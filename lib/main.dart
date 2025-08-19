// lib/main.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'routes.dart';
import 'pages/disaster_detail_page.dart';
import 'pages/initial_page.dart';
import 'pages/map_page.dart';
/// =====================
///  서버 URL
/// =====================
const String API_BASE = 'http://54.253.211.96:8000';
Uri _fcmRegisterUri() => Uri.parse('$API_BASE/api/users/fcm-token');

/// =====================
///  인증 토큰 보관
/// =====================
class Auth {
  static final _storage = const FlutterSecureStorage();
  static const _kAccessToken = 'access_token';
  static String? _cached;

  static Future<void> setAccessToken(String token) async {
    _cached = token;
    await _storage.write(key: _kAccessToken, value: token);
    // 로그인 직후 바로 FCM 등록 시도
    await registerFcmAfterAuth();
  }

  static Future<String?> getAccessToken() async {
    if (_cached != null && _cached!.isNotEmpty) return _cached;
    _cached = await _storage.read(key: _kAccessToken);
    return _cached;
  }

  static Map<String, String> headersJson() => {
    'Content-Type': 'application/json',
    if (_cached != null && _cached!.isNotEmpty)
      'Authorization': 'Bearer $_cached',
  };
}

/// =====================
///  재난 모델(예시)
/// =====================
final mockDisaster = Disaster(
  region: '부산광역시',
  type: '태풍',
  disasterLevel: '경계',
  startTime: '2025-07-21 14:30',
  info:
  '태풍 카눈이 부산에 접근 중입니다. 해안가 접근을 삼가시고 실내에 머무르시기 바랍니다. 시설물 피해 및 침수 주의 바랍니다.',
);

/// =====================
///  권한
/// =====================
Future<void> requestNotificationPermission() async {
  final status = await Permission.notification.status;
  if (!status.isGranted) {
    final result = await Permission.notification.request();
    print("알림 권한 요청 결과: $result");
  }
}

/// =====================
///  Local Notifications
/// =====================
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'default_channel_id',
  '기본 채널',
  description: '기본 알림 채널입니다.',
  importance: Importance.high,
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("백그라운드 메시지 수신: ${message.notification?.title}");
}

/// =====================
///  FCM 등록/갱신 로직
/// =====================

/// FCM 토큰을 가져오되, 초기 null 대응을 위해 약간 재시도
Future<String?> _ensureFcmToken({int retries = 5}) async {
  String? t = await FirebaseMessaging.instance.getToken();
  int left = retries;
  while ((t == null || t.isEmpty) && left > 0) {
    await Future.delayed(const Duration(milliseconds: 400));
    t = await FirebaseMessaging.instance.getToken();
    left--;
  }
  return t;
}

/// 로그인 직후 또는 앱 시작 시(저장된 액세스 토큰 있을 때) 호출
Future<void> registerFcmAfterAuth() async {
  try {
    final access = await Auth.getAccessToken();
    if (access == null || access.isEmpty) {
      print('액세스 토큰 없음. FCM 등록 보류');
      return;
    }

    final fcm = await _ensureFcmToken();
    print('FCM getToken(): $fcm');
    if (fcm == null || fcm.isEmpty) {
      print('FCM 토큰 없음. 등록 중단');
      return;
    }

    final body = jsonEncode({'fcm_token': fcm, 'platform': Platform.isIOS ? 'ios' : 'android'});

    final res = await http
        .post(_fcmRegisterUri(), headers: Auth.headersJson(), body: body)
        .timeout(const Duration(seconds: 8));

    print('POST ${_fcmRegisterUri()} -> ${res.statusCode} ${res.body}');
    if (res.statusCode >= 200 && res.statusCode < 300) {
      print('FCM 토큰 서버 등록 완료');
    } else {
      print('서버 에러: ${res.statusCode} ${res.body}');
    }
  } catch (e) {
    print('FCM 등록 실패: $e');
  }
}

/// 토큰 리프레시 시 서버 갱신(액세스 토큰이 있을 때만)
void bindFcmTokenRefreshListener() {
  FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
    try {
      final access = await Auth.getAccessToken();
      if (access == null || access.isEmpty) {
        print('액세스 토큰 없음. onTokenRefresh 갱신 스킵');
        return;
      }
      final body = jsonEncode({'fcm_token': t, 'platform': Platform.isIOS ? 'ios' : 'android'});
      final res = await http
          .post(_fcmRegisterUri(), headers: Auth.headersJson(), body: body)
          .timeout(const Duration(seconds: 8));
      print('onTokenRefresh POST -> ${res.statusCode} ${res.body}');
    } catch (e) {
      print('onTokenRefresh 갱신 실패: $e');
    }
  });
}

/// =====================
///  main
/// =====================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await requestNotificationPermission();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  // 포그라운드 수신 → 로컬 알림 표시
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    final android = message.notification?.android;
    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'default_channel_id',
            '기본 채널',
            channelDescription: '기본 알림 채널입니다.',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  });

  // FCM 리스너 바인딩
  bindFcmTokenRefreshListener();

  // 앱 시작 시, 저장된 액세스 토큰이 있다면 자동 등록 시도
  // (최초 설치 직후엔 토큰이 없으므로 로그인 성공 시 setAccessToken에서 처리됨)
  final saved = await Auth.getAccessToken();
  if (saved != null && saved.isNotEmpty) {
    await registerFcmAfterAuth();
  }

  // 네이버 지도 초기화
  final naverMap = FlutterNaverMap();
  await naverMap.init(
    clientId: 'p9nizolo1p',
    onAuthFailed: (e) => debugPrint('NaverMap Auth Failed: $e'),
  );

  runApp(const MyApp());
}

/// =====================
///  앱 위젯
/// =====================
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My App',
      initialRoute: '/initial',
      routes: {
        ...routes,
        '/initial': (context) => const InitialPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/disasterDetail') {
          final disaster = settings.arguments as Disaster;
          return MaterialPageRoute(
            builder: (context) => DisasterDetailPage(disaster: disaster),
          );
        }
        return MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: Center(child: Text('페이지를 찾을 수 없습니다')),
          ),
        );
      },
    );
  }
}

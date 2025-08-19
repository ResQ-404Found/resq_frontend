import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'routes.dart';
import 'pages/disaster_detail_page.dart';
import 'pages/map_page.dart';
import 'pages/initial_page.dart';
import 'package:permission_handler/permission_handler.dart';

final mockDisaster = Disaster(
  region: '부산광역시',
  type: '태풍',
  disasterLevel: '경계',
  startTime: '2025-07-21 14:30',
  info: '태풍 카눈이 부산에 접근 중입니다. 해안가 접근을 삼가시고 실내에 머무르시기 바랍니다. 시설물 피해 및 침수 주의 바랍니다.',
);

Future<void> requestNotificationPermission() async {
  final status = await Permission.notification.status;
  if (!status.isGranted) {
    final result = await Permission.notification.request();
    print("🔔 알림 권한 요청 결과: $result");
  }
}

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
  print("📩 백그라운드 메시지 수신: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await requestNotificationPermission();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // ✅ 초기화 시 앱 로고 아이콘 사용
  const initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@drawable/logo'),
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("🔔 알림 수신: ${message.notification?.title} / ${message.notification?.body}");
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      print("🧪 알림 표시 시도!");
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'default_channel_id',
            '기본 채널',
            channelDescription: '기본 알림 채널입니다.',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/logo', // ✅ 여기서도 앱 로고 아이콘 지정
          ),
        ),
      );
    } else {
      print("❌ 알림이 없거나 android 설정이 null입니다");
    }
  });

  final naverMap = FlutterNaverMap();
  await naverMap.init(
    clientId: 'p9nizolo1p',
    onAuthFailed: (e) => debugPrint('NaverMap Auth Failed: $e'),
  );

  runApp(const MyApp());
}

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

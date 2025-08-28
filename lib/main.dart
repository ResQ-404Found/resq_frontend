import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:resq_frontend/pages/login_page.dart';
import 'package:home_widget/home_widget.dart';
import 'package:resq_frontend/pages/friend_page.dart';
import 'routes.dart'; // uses AppRoutes/AppRouter
import 'package:home_widget/home_widget.dart';
import 'pages/disaster_detail_page.dart'; // for the Disaster type

const String _apiBase = 'http://54.253.211.96:8000';
Future<void> requestNotificationPermission() async {
  final status = await Permission.notification.status;
  if (!status.isGranted) {
    final result = await Permission.notification.request();
    // ignore: avoid_print
    print("🔔 알림 권한 요청 결과: $result");
  }
}
Future<void> updateDisasterWidget(bool hasDisaster) async {
  await HomeWidget.saveWidgetData<String>(
    'disaster_status',
    hasDisaster ? '⚠️ 재난 문자가 있습니다!' : '✅ 재난 문자가 없습니다.',
  );

  await HomeWidget.updateWidget(
    name: 'DisasterWidgetProvider',
    iOSName: 'DisasterWidget',
  );
}
/// 홈 위젯 새로고침 & 버튼 액션 등록
Future<void> updateEmergencyWidget() async {
  // 혹시 메시지/설정값을 위젯에 저장하고 싶다면 이렇게 저장 가능
  await HomeWidget.saveWidgetData<String>(
    'message',
    '긴급 상황입니다. 연락 부탁합니다.',
  );

  // 실제 위젯 새로고침 + 버튼 누를 때 backgroundCallback 호출되도록 등록
  await HomeWidget.updateWidget(
    name: 'EmergencyWidgetProvider', // AndroidManifest에 등록한 Provider 이름
    iOSName: 'EmergencyWidget',      // iOS는 안 쓴다면 무시됨
    qualifiedAndroidName: 'send_emergency', // 버튼 눌렀을 때 Uri.host로 전달됨
  );
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
  // ignore: avoid_print
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

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

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

  final naverMap = FlutterNaverMap();
  await naverMap.init(
    clientId: 'p9nizolo1p',
    onAuthFailed: (e) => debugPrint('NaverMap Auth Failed: $e'),
  );
  await updateEmergencyWidget(); // 앱 시작 시 위젯 초기화

  HomeWidget.registerBackgroundCallback(backgroundCallback);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My App',

      // ✅ Start here
      initialRoute: AppRoutes.initial,

      // ✅ All navigation goes through the central router
      onGenerateRoute: AppRouter.generateRoute,

      // ✅ Safety net (avoids "Page not found")
      onUnknownRoute: (_) =>
          MaterialPageRoute(builder: (_) => LoginPage()),
    );
  }
}
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? data) async {
  if (data?.host == 'send_emergency') {
    final api = ApiClient(baseUrl: _apiBase);
    final svc = EmergencyService(api);
    await svc.sendBroadcast(
      message: '긴급 상황입니다. 연락 부탁합니다.',
      includeLocation: true,
    );
  }
}
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print("FCM permission: ${settings.authorizationStatus}");

    final fcmToken = await _messaging.getToken();
    print("FCM TOKEN: $fcmToken");

    if (fcmToken != null) {
      await sendTokenToBackend(fcmToken);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print("FCM TOKEN REFRESHED: $newToken");
      await sendTokenToBackend(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Foreground notification:");
      print("Title: ${message.notification?.title}");
      print("Body: ${message.notification?.body}");
      print("Data: ${message.data}");
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Notification clicked: ${message.data}");
    });
  }

  Future<void> sendTokenToBackend(String fcmToken) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final idToken = await user.getIdToken(true);

    final response = await http.put(
      Uri.parse("http://192.168.10.9:5000/api/users/me/fcm-token"),
      headers: {
        "Authorization": "Bearer $idToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "fcmToken": fcmToken,
      }),
    );

    print("Save FCM token status: ${response.statusCode}");
    print("Save FCM token body: ${response.body}");
  }
}
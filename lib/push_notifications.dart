import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

// Initialize Flutter Local Notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Background notification handler (when the app is in the background or terminated)
Future<void> handleBackgroundMessage(RemoteMessage message) async {
  print(
      " Background Notification: ${message.notification?.title} - ${message.notification?.body}");
  showNotification(message); // Ensure background notifications are shown
}

// Function to display local notifications
void showNotification(RemoteMessage message) async {
  RemoteNotification? notification = message.notification;
  AndroidNotification? android = message.notification?.android;

  if (notification != null && android != null) {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel', // Same ID as defined in `main.dart`
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformChannelSpecifics,
      payload: message.data['ammonia_level'] ?? '',
    );
  }
}

class PushNotifications {
  final _firebaseMessaging = FirebaseMessaging.instance;

  // Initialize Firebase Cloud Messaging (FCM) notifications
  Future<void> initNotifications() async {
    // Request user permission for push notifications (iOS/Android)
    await _firebaseMessaging.requestPermission(
      alert: false,
      badge: true,
      sound: true,
    );

    // Get and print FCM token (used to identify the device)
    final fcmToken = await _firebaseMessaging.getToken();
    print("🔑 FCM Token: $fcmToken");

    // Set up background notification handler
    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);

    // Listen for foreground notifications (when the app is open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(
          " Foreground Notification: ${message.notification?.title} - ${message.notification?.body}");
      // showNotification(message); // Show local notification in foreground
      if (message.data.isNotEmpty) {
        showNotification(message); // Show notification only if SNS sends one
      }
    });

    // Listen for when the user taps a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("📲 User tapped on notification: ${message.data}");
    });

    // Initialize Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }
}

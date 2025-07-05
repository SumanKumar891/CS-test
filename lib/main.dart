import 'dart:convert';
import 'package:cloud_sense_webapp/AccountInfo.dart';
import 'package:cloud_sense_webapp/DeviceGraphPage.dart';
import 'package:cloud_sense_webapp/DeviceListPage.dart';
import 'package:cloud_sense_webapp/LoginPage.dart';
import 'package:cloud_sense_webapp/buffalodata.dart';
import 'package:cloud_sense_webapp/cowdata.dart';
import 'package:cloud_sense_webapp/map.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'HomePage.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:cloud_sense_webapp/amplifyconfiguration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_sense_webapp/push_notifications.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

// Initialize Flutter local notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Background message handler for Firebase Messaging
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
  if (message.data.isNotEmpty) {
    await showNotification(message);
  }
}

// Function to show local notifications
Future<void> showNotification(RemoteMessage message) async {
  RemoteNotification? notification = message.notification;
  AndroidNotification? android = message.notification?.android;

  if (notification != null && android != null) {
    String? title = notification.title ?? "Notification";
    String? body = notification.body;
    String? payload =
        message.data['ammonia_level'] ?? message.data['gps_movement'] ?? '';

    if (message.data.containsKey('gps_movement')) {
      title = "GPS Device Movement";
      body =
          "Device ${message.data['device_id']} has moved: ${message.data['gps_movement']}";
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel',
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
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }
}

Future<void> handleLoginAndSubscribe(String userEmail, String fcmToken) async {
  print("User logged in: $userEmail");

  if (userEmail == '05agriculture.05@gmail.com') {
    print("Matched user: $userEmail - triggering GPS topic subscription.");
    await subscribeToGpsSnsTopic(fcmToken);
  } else {
    print("User $userEmail is not configured for auto-subscription.");
  }
}

Future<void> subscribeToGpsSnsTopic(String fcmToken) async {
  print("Subscribing device to GPS SNS topic with token: $fcmToken");

  const String snsTopicArn =
      'arn:aws:sns:us-east-1:396608808412:GPS_Notification';
  const String apiGatewayUrl =
      'https://cpkutjaqel.execute-api.us-east-1.amazonaws.com/default/sns_api_fcm_updation';

  try {
    var requestBody = jsonEncode({
      'action': 'subscribe',
      'snsTopicArn': snsTopicArn,
      'fcmToken': fcmToken,
    });

    print("POST request sent to subscribe GPS: $requestBody");

    var response = await http.post(
      Uri.parse(apiGatewayUrl),
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );

    print(
        "Subscribe GPS API response: ${response.statusCode} - ${response.body}");

    if (response.statusCode == 200) {
      print("Device subscribed to GPS SNS topic successfully.");
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isGpsTokenSubscribed', true);
    } else {
      print("Failed to subscribe to GPS SNS topic: ${response.statusCode}");
    }
  } catch (e) {
    print("Error subscribing to GPS SNS topic: $e");
  }
}

// Unsubscribe device from GPS SNS topic
Future<void> unsubscribeFromGpsSnsTopic(String fcmToken) async {
  print("Unsubscribing device from GPS SNS topic with token: $fcmToken");
  const String apiGatewayUrl =
      'https://cpkutjaqel.execute-api.us-east-1.amazonaws.com/default/sns_api_fcm_updation';

  try {
    var requestBody = jsonEncode({
      'action': 'unsubscribe',
      'fcmToken': fcmToken,
    });
    print("Sending POST request to unsubscribe GPS: $requestBody");

    var response = await http.post(
      Uri.parse(apiGatewayUrl),
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );

    print(
        "Unsubscribe GPS API response: ${response.statusCode} - ${response.body}");
    if (response.statusCode == 200) {
      print("Device unsubscribed from GPS SNS topic successfully.");
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('isGpsTokenSubscribed');
    } else {
      print("Failed to unsubscribe from GPS SNS topic: ${response.statusCode}");
    }
  } catch (e) {
    print("Error unsubscribing from GPS SNS topic: $e");
  }
}

Future<void> manageNotificationSubscription() async {
  print("Starting manageNotificationSubscription...");

  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? email = prefs.getString('email');
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  if (email == null) {
    print("No user logged in. Skipping notification subscriptions.");
    return;
  }

  try {
    String? token = await messaging.getToken();
    if (token == null) {
      print("Failed to retrieve FCM token.");
      return;
    }

    print("User logged in: $email");
    print("FCM Token: $token"); // Moved outside conditional branches

    if (email == "05agriculture.05@gmail.com") {
      print("GPS notifications allowed for this user.");
      bool? isGpsSubscribed = prefs.getBool('isGpsTokenSubscribed');
      if (isGpsSubscribed != true) {
        await subscribeToGpsSnsTopic(token);
        await prefs.setBool('isGpsTokenSubscribed', true);
      } else {
        print("Already subscribed to GPS SNS topic.");
      }
      // Ensure ammonia is unsubscribed
      bool? wasAmmoniaSubscribed = prefs.getBool('isAmmoniaTokenSubscribed');
      if (wasAmmoniaSubscribed == true) {
        await unsubscribeFromSnsTopic(token);
        await prefs.remove('isAmmoniaTokenSubscribed');
      }
    } else {
      bool hasAmmoniaSensor = await userHasAmmoniaSensor(email);
      if (hasAmmoniaSensor) {
        print(
            "NH sensor found for user. Subscribing to ammonia notifications.");
        bool? isAmmoniaSubscribed = prefs.getBool('isAmmoniaTokenSubscribed');
        if (isAmmoniaSubscribed != true) {
          await subscribeToSnsTopic(token);
          await prefs.setBool('isAmmoniaTokenSubscribed', true);
        } else {
          print("Already subscribed to ammonia SNS topic.");
        }
      } else {
        print("No NH sensor found. Unsubscribing if previously subscribed.");
        bool? wasSubscribed = prefs.getBool('isAmmoniaTokenSubscribed');
        if (wasSubscribed == true) {
          await unsubscribeFromSnsTopic(token);
          await prefs.remove('isAmmoniaTokenSubscribed');
        }
      }
      // Ensure GPS is unsubscribed for non-authorized users
      bool? isGpsSubscribed = prefs.getBool('isGpsTokenSubscribed');
      if (isGpsSubscribed == true) {
        await unsubscribeFromGpsSnsTopic(token);
        await prefs.remove('isGpsTokenSubscribed');
      }
    }
  } catch (e) {
    print("Error managing notification subscriptions: $e");
  }

  print("manageNotificationSubscription completed.");
}

// Method to check and update notification subscription
Future<void> checkAndUpdateNotificationSubscription() async {
  await manageNotificationSubscription();
}

// Existing ammonia-specific methods (unchanged)
Future<bool> userHasAmmoniaSensor(String email) async {
  final String apiUrl =
      'https://ln8b1r7ld9.execute-api.us-east-1.amazonaws.com/default/Cloudsense_user_devices?email_id=$email';

  try {
    var response = await http.get(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
    );
    print("Checking NH sensor for user: $email");

    if (response.statusCode == 200) {
      try {
        var data = jsonDecode(response.body);
        if (data.containsKey("NH") && (data["NH"] as List).isNotEmpty) {
          print("Ammonia sensor found!");
          return true;
        } else {
          print("No ammonia sensor found.");
        }
      } catch (e) {
        print("Invalid JSON response from device API: ${response.body}");
        return false;
      }
    } else {
      print("Failed to fetch devices. Status Code: ${response.statusCode}");
    }
  } catch (e) {
    print("Error fetching device list: $e");
  }

  return false;
}

Future<void> subscribeToSnsTopic(String fcmToken) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? email = prefs.getString('email');

  if (email == null) {
    print("User is not logged in. Skipping ammonia SNS subscription.");
    return;
  }

  bool hasAmmoniaSensor = await userHasAmmoniaSensor(email);
  if (!hasAmmoniaSensor) {
    print("No NH sensor found in account. Skipping subscription.");
    return;
  }

  print("Subscribing device to ammonia SNS topic with token: $fcmToken");
  const String snsTopicArn =
      'arn:aws:sns:us-east-1:975048338421:CloudSense_Notification_NH';
  const String apiGatewayUrl =
      'https://2u9vg092x5.execute-api.us-east-1.amazonaws.com/default/sns_api_fcm_updation';

  try {
    var requestBody = jsonEncode({
      'action': 'subscribe',
      'snsTopicArn': snsTopicArn,
      'fcmToken': fcmToken,
    });
    print("Sending POST request to subscribe Ammonia: $requestBody");

    var response = await http.post(
      Uri.parse(apiGatewayUrl),
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );

    if (response.statusCode == 200) {
      print("Device subscribed to ammonia SNS topic successfully.");
      await prefs.setBool('isAmmoniaTokenSubscribed', true); // ✅ ADD THIS
    } else {
      print("Failed to subscribe to ammonia SNS topic: ${response.statusCode}");
    }
  } catch (e) {
    print("Error subscribing to ammonia SNS topic: $e");
  }
}

Future<void> unsubscribeFromSnsTopic(String fcmToken) async {
  const String apiGatewayUrl =
      'https://2u9vg092x5.execute-api.us-east-1.amazonaws.com/default/sns_api_fcm_updation';

  try {
    var requestBody = jsonEncode({
      'action': 'unsubscribe',
      'fcmToken': fcmToken,
    });
    print("Sending POST request to unsubscribe Ammonia: $requestBody");

    var response = await http.post(
      Uri.parse(apiGatewayUrl),
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );
    print("Unsubscribe ammonia API Response: ${response.body}");

    if (response.statusCode == 200) {
      print("Device unsubscribed from ammonia SNS topic successfully.");
    } else {
      print(
          "Failed to unsubscribe from ammonia SNS topic: ${response.statusCode}");
    }
  } catch (e) {
    print("Error unsubscribing from ammonia SNS topic: $e");
  }
}

// Setup and configure local notifications
Future<void> setupNotifications() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
    playSound: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  const InitializationSettings initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );

  await flutterLocalNotificationsPlugin.initialize(initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
    print("User tapped on notification: ${details.payload}");
  });
}

Future<String> determineInitialRoute() async {
  try {
    var currentUser = await Amplify.Auth.getCurrentUser();
    var userAttributes = await Amplify.Auth.fetchUserAttributes();
    String? email;
    for (var attr in userAttributes) {
      if (attr.userAttributeKey == AuthUserAttributeKey.email) {
        email = attr.value;
        break;
      }
    }

    if (email != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('email', email); // ✅ Save email here
    }

    print(
        'Determining initial route - User ID: ${currentUser.username}, Email: $email');
    if (email?.trim().toLowerCase() == '05agriculture.05@gmail.com') {
      print('Initial route set to /deviceinfo');
      return '/deviceinfo';
    } else {
      print('Initial route set to /devicelist');
      return '/devicelist';
    }
  } catch (e) {
    print('No user logged in or error: $e');
    return '/';
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setPathUrlStrategy();

  await setupNotifications();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyC8VgXQxru1bzlbLTUvOc4o490gxDc_MDQ",
        authDomain: "cloudsense-cba8a.firebaseapp.com",
        projectId: "cloudsense-cba8a",
        storageBucket: "cloudsense-cba8a.firebasestorage.app",
        messagingSenderId: "209940213885",
        appId: "1:209940213885:web:1b68309df786c4c30fc114",
        measurementId: "G-HMXS0HV32J",
      ),
    );
  } else {
    await Firebase.initializeApp();
    await PushNotifications().initNotifications();
  }

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: false,
    badge: false,
    sound: false,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    await Amplify.addPlugin(AmplifyAuthCognito());
    await Amplify.configure(amplifyconfig);
  } catch (e) {
    print('Could not configure Amplify: $e');
  }

  // Manage subscriptions for both ammonia and GPS
  await manageNotificationSubscription();

  // Listen for FCM token refreshes and update subscriptions
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    print("FCM token refreshed: $newToken");
    await manageNotificationSubscription();
  });

  // Determine initial route based on user authentication
  String initialRoute = await determineInitialRoute();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MyApp(initialRoute: initialRoute),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  MyApp({required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Cloud Sense Vis',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.isDarkMode ? ThemeData.dark() : ThemeData.light(),
      initialRoute: initialRoute,
      routes: {
        '/': (context) => HomePage(),
        '/about-us': (context) =>
            HomePage(), // Note: Consider a dedicated AboutUsPage
        '/login': (context) => SignInSignUpScreen(),
        '/accountinfo': (context) => AccountInfoPage(),
        '/deviceinfo': (context) => MapPage(),
        '/devicelist': (context) => DataDisplayPage(),
        '/devicegraph': (context) => DeviceGraphPage(
              deviceName: '',
              sequentialName: null,
              backgroundImagePath: '',
            ),
        '/buffalodata': (context) => BuffaloData(
              startDateTime: DateTime.now(),
              endDateTime: DateTime.now().add(Duration(days: 1)),
              nodeId: '',
            ),
        '/cowdata': (context) => CowData(
              startDateTime: DateTime.now(),
              endDateTime: DateTime.now().add(Duration(days: 1)),
              nodeId: '',
            ),
      },
    );
  }
}

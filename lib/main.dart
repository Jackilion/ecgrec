import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home.dart';
import 'io_manager.dart';
import 'notification_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //Init Push Notis
  final notifManager = NotificationManager();
  await notifManager.flutterLocalNotificationsPlugin
      .getNotificationAppLaunchDetails();
  // initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await notifManager.flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) {});
  final ioManager = IOManager();
  ioManager.path = await getExternalStorageDirectory();
  final prefs = await SharedPreferences.getInstance();
  final deviceId = prefs.getString("deviceId");
  if (deviceId != null) {
    ioManager.deviceId = deviceId;
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: WillPopScope(
            onWillPop: () async {
              return false;
            },
            child: const Home()));
  }
}

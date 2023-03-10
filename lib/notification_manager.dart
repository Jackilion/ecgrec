import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationManager {
  NotificationManager._internal();
  static final NotificationManager _notificationManager =
      NotificationManager._internal();
  factory NotificationManager() {
    return _notificationManager;
  }

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  Future<void> init() async {}

  Future<void> showNotification(String title, String body) async {
    const androidNotificationDetails = AndroidNotificationDetails("1", "status",
        channelDescription: "Test",
        importance: Importance.max,
        priority: Priority.high,
        ongoing: true,
        showWhen: false,
        autoCancel: false);
    const notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    flutterLocalNotificationsPlugin.show(
      1,
      title,
      body,
      notificationDetails,
    );
  }
}

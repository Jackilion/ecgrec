import 'package:ecgrec/home.dart';
import 'package:ecgrec/io_manager.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ioManager = IOManager();
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
        home: const Home());
  }
}

import 'package:flutter/material.dart';
import 'screens/home_alarm_screen.dart';
import 'services/alarm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlarmService().init();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HomeAlarmScreen(),
  ));
}
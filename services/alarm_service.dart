import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final FlutterLocalNotificationsPlugin localNotif = FlutterLocalNotificationsPlugin();
  final AudioPlayer audioPlayer = AudioPlayer();
  static const String channelId = 'nabd_alarm_channel_v4';
  static const String channelName = 'منبه نبض كلوك';

  Future<void> init() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    await localNotif.initialize(initSettings, onDidReceiveNotificationResponse: (NotificationResponse response) { stopAlarmSound(); });
    await _createAlarmChannel();
    await requestAllPermissions();
  }

  Future<void> _createAlarmChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(channelId, channelName, description: 'قناة المنبه', importance: Importance.max);
    await localNotif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  }

  Future<bool> requestAllPermissions() async {
    if (await Permission.notification.isDenied) await Permission.notification.request();
    final androidPlugin = localNotif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final canExact = await androidPlugin?.canScheduleExactAlarms() ?? false;
    if (!canExact) await androidPlugin?.requestExactAlarmsPermission();
    return true;
  }

  Future<String?> pickToneFromPhone() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) return result.files.single.path!;
    return null;
  }

  Future<void> previewSound(String path) async {
    await audioPlayer.stop();
    await audioPlayer.play(DeviceFileSource(path));
  }

  Future<void> stopAlarmSound() async {
    await audioPlayer.stop();
    await localNotif.cancelAll();
  }

  Future<void> scheduleRealAlarm({required int id, required String title, required DateTime scheduledTime, String? customPhoneAudioPath}) async {
    await localNotif.zonedSchedule(id, title, 'حان وقت المنبه!', tz.TZDateTime.from(scheduledTime, tz.local), NotificationDetails(android: AndroidNotificationDetails(channelId, channelName, importance: Importance.max, priority: Priority.high, fullScreenIntent: true, category: AndroidNotificationCategory.alarm, playSound: false, enableVibration: true)), androidScheduleMode: AndroidScheduleMode.alarmClock, uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
    if (customPhoneAudioPath != null) {
      await audioPlayer.setReleaseMode(ReleaseMode.loop);
      await audioPlayer.play(DeviceFileSource(customPhoneAudioPath));
    }
  }
}
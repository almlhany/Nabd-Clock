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

  // ⚠️ غيّر اسم القناة دائماً لكسر كاش أندرويد القديم
  static const String channelId = 'nabd_alarm_channel_v3';
  static const String channelName = 'منبه نبض كلوك الرئيسي';

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        stopAlarmSound();
      },
    );

    await _createAlarmChannel();
    await requestAllPermissions();
  }

  Future<void> _createAlarmChannel() async {
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: 'قناة المنبه بصوت حقيقي عالي مستمر',
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('alarm_tone'),
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm, // ⚠️ ضروري ليتحكم به شريط صوت المنبه
    );

    await localNotif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<bool> requestAllPermissions() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    final androidPlugin = localNotif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final canExact = await androidPlugin?.canScheduleExactAlarms() ?? false;
    if (!canExact) {
      await androidPlugin?.requestExactAlarmsPermission();
    }

    if (Platform.isAndroid) {
      if (await Permission.audio.isDenied) {
        await Permission.audio.request();
      }
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
    }
    return true;
  }

  /// 📁 دالة زر اختيار نغمة تنبيه من الهاتف
  Future<String?> pickToneFromPhone() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        return result.files.single.path!;
      }
    } catch (e) {
      print('خطأ في اختيار نغمة من الهاتف: $e');
    }
    return null;
  }

  Future<void> previewSound(String path) async {
    await audioPlayer.stop();
    await audioPlayer.play(DeviceFileSource(path));
  }

  Future<void> stopAlarmSound() async {
    await audioPlayer.stop();
  }

  Future<void> scheduleRealAlarm({
    required int id,
    required String title,
    required DateTime scheduledTime,
    String? customPhoneAudioPath,
  }) async {
    await localNotif.zonedSchedule(
      id,
      title,
      'حان وقت المنبه! اضغط لإيقاف الرنين',
      tz.TZDateTime.from(scheduledTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'تنبيه بصوت عالي مستمر',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true, // ⚠️ يوقظ الشاشة حتى لو كانت مقفلة ومطفية
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('alarm_tone'),
          enableVibration: true,
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'stop_action',
              'إيقاف المنبه',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock, // ⚠️ يوقظ المعالج في وضع سكون البطارية
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
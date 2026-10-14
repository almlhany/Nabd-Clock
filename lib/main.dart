import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ساعة التنبيه الاحترافية',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFFF59E0B),
        ),
      ),
      home: const AlarmHomeScreen(),
    );
  }
}

// كلاس لحساب التاريخ الهجري رياضياً بدقة
class HijriHelper {
  static String getHijriDate(DateTime date) {
    double jd = date.year + (date.month + 9.0) / 12.0;
    jd = 367.0 * date.year -
        ((7.0 * jd) / 4.0).floor() +
        ((275.0 * date.month) / 9.0).floor() +
        date.day +
        1721013.5;
    double l = jd - 1948440.0 + 10632.0;
    double n = ((l - 1.0) / 10631.0).floorToDouble();
    l = l - 10631.0 * n + 354.0;
    double j = (((10985.0 - l) / 5316.0).floorToDouble()) *
            (((50.0 * l) / 17719.0).floorToDouble()) +
        ((l / 5670.0).floorToDouble()) *
            (((43.0 * l) / 15238.0).floorToDouble());
    l = l -
        (((30.0 - j) / 15.0).floorToDouble()) *
            (((17719.0 * j) / 50.0).floorToDouble()) -
        ((j / 16.0).floorToDouble()) * (((15238.0 * j) / 43.0).floorToDouble()) +
        29.0;
    int m = ((24.0 * l) / 709.0).floor();
    int d = (l - ((709.0 * m) / 24.0).floor()).toInt();
    int y = (30.0 * n + j - 30.0).toInt();

    const months = [
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الآخر',
      'جمادى الأولى',
      'جمادى الآخرة',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة'
    ];
    int safeMonth = (m - 1).clamp(0, 11);
    return '$d ${months[safeMonth]} $y هـ';
  }
}

class AlarmHomeScreen extends StatefulWidget {
  const AlarmHomeScreen({super.key});

  @override
  State<AlarmHomeScreen> createState() => _AlarmHomeScreenState();
}

class _AlarmHomeScreenState extends State<AlarmHomeScreen> {
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();

  TimeOfDay _alarmTime = const TimeOfDay(hour: 6, minute: 30);
  bool _isAlarmEnabled = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String _selectedRingtoneName = 'رنين كلاسيكي هادئ';
  String? _customAudioPath;
  bool _isRinging = false;

  final List<Map<String, String>> _builtInRingtones = [
    {
      'name': 'رنين كلاسيكي هادئ',
      'url': 'https://actions.google.com/sounds/v1/alarms/alarm_clock.ogg'
    },
    {
      'name': 'جرس الصباح النقي',
      'url': 'https://actions.google.com/sounds/v1/alarms/digital_watch_alarm_long.ogg'
    },
    {
      'name': 'نغمة إلكترونية حديثة',
      'url': 'https://actions.google.com/sounds/v1/alarms/beep_short.ogg'
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
    _startClockAndAlarmMonitor();
  }

  void _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      int hour = prefs.getInt('alarm_hour') ?? 6;
      int minute = prefs.getInt('alarm_minute') ?? 30;
      _alarmTime = TimeOfDay(hour: hour, minute: minute);
      _isAlarmEnabled = prefs.getBool('alarm_enabled') ?? false;
      _selectedRingtoneName =
          prefs.getString('ringtone_name') ?? 'رنين كلاسيكي هادئ';
      _customAudioPath = prefs.getString('custom_audio_path');
    });
  }

  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('alarm_hour', _alarmTime.hour);
    await prefs.setInt('alarm_minute', _alarmTime.minute);
    await prefs.setBool('alarm_enabled', _isAlarmEnabled);
    await prefs.setString('ringtone_name', _selectedRingtoneName);
    if (_customAudioPath != null) {
      await prefs.setString('custom_audio_path', _customAudioPath!);
    }
  }

  void _startClockAndAlarmMonitor() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      setState(() {
        _currentTime = now;
      });

      // التحقق من موعد التنبيه بدقة بالثانية الصفرية
      if (_isAlarmEnabled && !_isRinging) {
        if (now.hour == _alarmTime.hour &&
            now.minute == _alarmTime.minute &&
            now.second == 0) {
          _triggerAlarm();
        }
      }
    });
  }

  void _triggerAlarm() async {
    setState(() {
      _isRinging = true;
    });

    _audioPlayer.setReleaseMode(ReleaseMode.loop);

    try {
      if (_customAudioPath != null && File(_customAudioPath!).existsSync()) {
        await _audioPlayer.play(DeviceFileSource(_customAudioPath!));
      } else {
        var ringtone = _builtInRingtones.firstWhere(
          (element) => element['name'] == _selectedRingtoneName,
          orElse: () => _builtInRingtones.first,
        );
        await _audioPlayer.play(UrlSource(ringtone['url']!));
      }
    } catch (_) {
      // في حال تعذر تشغيل ملف خارجي يتم تشغيل النغمة الأساسية
      await _audioPlayer.play(UrlSource(_builtInRingtones.first['url']!));
    }

    // اهتزاز الجهاز باستمرار
    HapticFeedback.vibrate();

    if (mounted) {
      _showAlarmDialog();
    }
  }

  void _stopAlarm() async {
    await _audioPlayer.stop();
    setState(() {
      _isRinging = false;
    });
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _snoozeAlarm(int minutes) {
    _stopAlarm();
    final now = DateTime.now().add(Duration(minutes: minutes));
    setState(() {
      _alarmTime = TimeOfDay(hour: now.hour, minute: now.minute);
      _isAlarmEnabled = true;
    });
    _saveSettings();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تأجيل المنبه لمدة $minutes دقائق'),
        backgroundColor: const Color(0xFFF59E0B),
      ),
    );
  }

  void _showAlarmDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Column(
            children: [
              Icon(Icons.alarm_on, size: 70, color: Color(0xFFEF4444)),
              SizedBox(height: 12),
              Text(
                'استيقظ! حان وقت التنبيه',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            'الوقت الحالي: ${DateFormat('hh:mm a', 'ar').format(DateTime.now())}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _snoozeAlarm(5),
              icon: const Icon(Icons.snooze, color: Colors.black),
              label: const Text(
                'غفوة (5 د)',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _stopAlarm,
              icon: const Icon(Icons.stop, color: Colors.white),
              label: const Text(
                'إيقاف المنبه',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAlarmTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _alarmTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF38BDF8),
              surface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _alarmTime = picked;
        _isAlarmEnabled = true;
      });
      _saveSettings();
    }
  }

  Future<void> _pickCustomAudioFromPhone() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'ogg'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _customAudioPath = result.files.single.path;
          _selectedRingtoneName = result.files.single.name;
        });
        _saveSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تعيين النغمة: $_selectedRingtoneName'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر الوصول لملف الصوت')),
      );
    }
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hijriDate = HijriHelper.getHijriDate(_currentTime);
    final gregorianDate =
        DateFormat('EEEE، d MMMM yyyy', 'ar').format(_currentTime);
    final timeFormatted = DateFormat('hh:mm:ss', 'ar').format(_currentTime);
    final amPm = DateFormat('a', 'ar').format(_currentTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ساعة التنبيه الذكية',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            // بطاقة عرض التواريخ (ميلادي وهجري)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_month,
                          color: Color(0xFF38BDF8), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        gregorianDate,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hijriDate,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF59E0B)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // الساعة الرقمية الكبيرة
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30),
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  radius: 0.9,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    blurRadius: 25,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    timeFormatted,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                  Text(
                    amPm,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // كرت تحديد وتفعيل المنبه
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'وقت التنبيه القادم',
                            style:
                                TextStyle(fontSize: 14, color: Colors.white60),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: _pickAlarmTime,
                            child: Text(
                              _alarmTime.format(context),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isAlarmEnabled,
                        activeColor: const Color(0xFF38BDF8),
                        onChanged: (val) {
                          setState(() {
                            _isAlarmEnabled = val;
                          });
                          _saveSettings();
                        },
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 25),
                  // اختيار النغمة
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'النغمة الحالية:',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      DropdownButton<String>(
                        value: _customAudioPath == null
                            ? _selectedRingtoneName
                            : null,
                        hint: Text(
                          _selectedRingtoneName,
                          style: const TextStyle(
                              color: Color(0xFFF59E0B), fontSize: 13),
                        ),
                        dropdownColor: const Color(0xFF1E293B),
                        underline: const SizedBox(),
                        items: _builtInRingtones.map((item) {
                          return DropdownMenuItem<String>(
                            value: item['name'],
                            child: Text(item['name']!),
                          );
                        }).toList(),
                        onChanged: (String? val) {
                          if (val != null) {
                            setState(() {
                              _selectedRingtoneName = val;
                              _customAudioPath = null;
                            });
                            _saveSettings();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // زر استيراد نغمة من ذاكرة الهاتف
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF334155),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _pickCustomAudioFromPhone,
                icon: const Icon(Icons.audio_file, color: Color(0xFF38BDF8)),
                label: const Text(
                  'اختيار نغمة مخصصة من الهاتف (MP3 / WAV)',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // زر التجربة السريعة (رنين بعد 10 ثوانٍ)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  final testTime =
                      DateTime.now().add(const Duration(seconds: 10));
                  setState(() {
                    _alarmTime = TimeOfDay(
                        hour: testTime.hour, minute: testTime.minute);
                    _isAlarmEnabled = true;
                  });
                  _saveSettings();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'سيبدأ التنبيه بعد 10 ثوانٍ.. يمكنك قفل الشاشة للتجربة'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                },
                icon: const Icon(Icons.timer, color: Colors.white),
                label: const Text(
                  'تجربة المنبه بعد 10 ثوانٍ',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
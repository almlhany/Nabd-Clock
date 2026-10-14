import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/alarm_service.dart';

class HomeAlarmScreen extends StatefulWidget {
  const HomeAlarmScreen({super.key});

  @override
  State<HomeAlarmScreen> createState() => _HomeAlarmScreenState();
}

class _HomeAlarmScreenState extends State<HomeAlarmScreen> {
  final AlarmService _alarmService = AlarmService();
  String _currentTimeStr = '';
  Timer? _clockTimer;

  final List<Map<String, dynamic>> _alarms = [];
  String? _selectedPhoneTonePath;
  String _selectedToneName = 'نغمة المنبه الافتراضية (alarm_tone)';
  bool _isPlayingPreview = false;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _alarmService.stopAlarmSound();
    super.dispose();
  }

  void _updateTime() {
    setState(() {
      _currentTimeStr = DateFormat('hh:mm:ss a').format(DateTime.now());
    });
  }

  // 📁 استدعاء زر إضافة نغمة من الهاتف
  Future<void> _pickRingtoneFromPhone() async {
    final path = await _alarmService.pickToneFromPhone();
    if (path != null) {
      setState(() {
        _selectedPhoneTonePath = path;
        _selectedToneName = path.split('/').last;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم اختيار النغمة من الهاتف: $_selectedToneName'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _togglePreviewSound() async {
    if (_isPlayingPreview) {
      await _alarmService.stopAlarmSound();
      setState(() => _isPlayingPreview = false);
    } else {
      if (_selectedPhoneTonePath != null) {
        setState(() => _isPlayingPreview = true);
        await _alarmService.previewSound(_selectedPhoneTonePath!);
        setState(() => _isPlayingPreview = false);
      }
    }
  }

  void _scheduleQuickTestAlarm() async {
    final scheduledTime = DateTime.now().add(const Duration(seconds: 10));
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _alarmService.scheduleRealAlarm(
      id: id,
      title: 'فحص فوري - منبه نبض كلوك',
      scheduledTime: scheduledTime,
      customPhoneAudioPath: _selectedPhoneTonePath,
    );

    setState(() {
      _alarms.add({
        'id': id,
        'title': 'فحص سريع (10 ثوانٍ)',
        'time': DateFormat('hh:mm a').format(scheduledTime),
        'tone': _selectedToneName,
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم جدولة المنبه! سيصدر التنبيه بعد 10 ثوانٍ...'),
        backgroundColor: Color(0xFFE11D48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نبض كلوك | Nabd Clock', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF111827),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE11D48).withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  const Text('الوقت الحالي الفعلي', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(_currentTimeStr, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 📁 بطاقة زر إضافة نغمات من الهاتف
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.library_music, color: Colors.amber),
                      SizedBox(width: 8),
                      Text('نغمة التنبيه المختارة:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(_selectedToneName, style: const TextStyle(color: Colors.amberAccent, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickRingtoneFromPhone,
                          icon: const Icon(Icons.file_upload),
                          label: const Text('اختيار نغمة من الهاتف'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_selectedPhoneTonePath != null)
                        IconButton.filled(
                          onPressed: _togglePreviewSound,
                          icon: Icon(_isPlayingPreview ? Icons.stop : Icons.play_arrow),
                          style: IconButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _scheduleQuickTestAlarm,
                icon: const Icon(Icons.alarm_on),
                label: const Text('فحص فوري للمنبه (بعد 10 ثوانٍ)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
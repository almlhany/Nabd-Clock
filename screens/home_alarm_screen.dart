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
  String _selectedToneName = 'نغمة افتراضية';
  bool _isPlayingPreview = false;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
    _alarmService.init();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _alarmService.stopAlarmSound();
    super.dispose();
  }

  void _updateTime() {
    if(!mounted) return;
    setState(() {
      _currentTimeStr = DateFormat('hh:mm:ss a').format(DateTime.now());
    });
  }

  Future<void> _pickRingtoneFromPhone() async {
    final path = await _alarmService.pickToneFromPhone();
    if (path != null) {
      setState(() {
        _selectedPhoneTonePath = path;
        _selectedToneName = path.split('/').last;
      });
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
        Future.delayed(Duration(seconds: 5), () async {
          await _alarmService.stopAlarmSound();
          if(mounted) setState(() => _isPlayingPreview = false);
        });
      }
    }
  }

  void _scheduleQuickTestAlarm() async {
    final scheduledTime = DateTime.now().add(const Duration(seconds: 10));
    final id = DateTime.now().millisecondsSinceEpoch % 100000;
    await _alarmService.scheduleRealAlarm(
      id: id,
      title: 'فحص منبه نبض كلوك',
      scheduledTime: scheduledTime,
      customPhoneAudioPath: _selectedPhoneTonePath,
    );
    setState(() {
      _alarms.add({'id': id, 'title': 'فحص سريع', 'time': DateFormat('hh:mm:ss a').format(scheduledTime), 'tone': _selectedToneName});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF111827),
      appBar: AppBar(title: const Text('نبض كلوك'), backgroundColor: const Color(0xFF111827), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(20)), child: Text(_currentTimeStr, textAlign: TextAlign.center, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white))),
          const SizedBox(height: 20),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber.withOpacity(0.4))), child: Column(children: [Text(_selectedToneName, style: const TextStyle(color: Colors.amberAccent)), const SizedBox(height: 12), Row(children: [Expanded(child: ElevatedButton.icon(onPressed: _pickRingtoneFromPhone, icon: const Icon(Icons.file_upload), label: const Text('اختيار نغمة من الهاتف'))), IconButton.filled(onPressed: _togglePreviewSound, icon: Icon(_isPlayingPreview ? Icons.stop : Icons.play_arrow))])])),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(onPressed: _scheduleQuickTestAlarm, icon: const Icon(Icons.alarm_on), label: const Text('فحص فوري (10 ثواني)'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white))),
        ]),
      ),
    );
  }
}
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm.dart';
import 'alarm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlarmService.init();
  runApp(const AlarmApp());
}

class AlarmApp extends StatelessWidget {
  const AlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ساعة المنبّه',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        fontFamily: 'Arial',
      ),
      home: const AlarmsPage(),
    );
  }
}

class AlarmsPage extends StatefulWidget {
  const AlarmsPage({super.key});

  @override
  State<AlarmsPage> createState() => _AlarmsPageState();
}

class _AlarmsPageState extends State<AlarmsPage> {
  List<Alarm> alarms = [];

  @override
  void initState() {
    super.initState();
    loadAlarms();
  }

  Future<void> loadAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('alarms');

    setState(() {
      alarms = raw == null ? [] : Alarm.decodeList(raw);
    });
  }

  Future<void> saveAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alarms', Alarm.encodeList(alarms));
  }

  Future<void> addAlarm() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked == null) return;

    final alarm = Alarm(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      hour: picked.hour,
      minute: picked.minute,
      enabled: true,
    );

    alarms.add(alarm);
    await saveAlarms();
    await scheduleAlarm(alarm);
    setState(() {});
  }

  Future<void> scheduleAlarm(Alarm alarm) async {
    final now = DateTime.now();

    var time = DateTime(
      now.year,
      now.month,
      now.day,
      alarm.hour,
      alarm.minute,
    );

    if (time.isBefore(now)) {
      time = time.add(const Duration(days: 1));
    }

    final notificationId = alarm.id.hashCode & 0x7fffffff;

    await AlarmService.schedule(
      id: notificationId,
      title: 'حان وقت المنبّه',
      body: 'المنبّه المضبوط على ${alarm.label}',
      time: time,
    );
  }

  Future<void> toggleAlarm(Alarm alarm) async {
    final index = alarms.indexWhere((a) => a.id == alarm.id);
    final updated = Alarm(
      id: alarm.id,
      hour: alarm.hour,
      minute: alarm.minute,
      enabled: !alarm.enabled,
    );

    alarms[index] = updated;
    await saveAlarms();

    final notificationId = alarm.id.hashCode & 0x7fffffff;

    if (updated.enabled) {
      await scheduleAlarm(updated);
    } else {
      await AlarmService.cancel(notificationId);
    }

    setState(() {});
  }

  Future<void> deleteAlarm(Alarm alarm) async {
    alarms.removeWhere((a) => a.id == alarm.id);
    await saveAlarms();
    await AlarmService.cancel(alarm.id.hashCode & 0x7fffffff);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ساعة المنبّه'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addAlarm,
        child: const Icon(Icons.alarm_add),
      ),
      body: alarms.isEmpty
          ? const Center(
              child: Text('لا توجد منبّهات بعد'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: alarms.length,
              itemBuilder: (context, index) {
                final alarm = alarms[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.alarm),
                    title: Text(
                      alarm.label,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: alarm.enabled,
                          onChanged: (_) => toggleAlarm(alarm),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => deleteAlarm(alarm),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
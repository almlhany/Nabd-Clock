import 'dart:convert';

class Alarm {
  final String id;
  final int hour;
  final int minute;
  final bool enabled;

  Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    required this.enabled,
  });

  String get label =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'enabled': enabled,
      };

  factory Alarm.fromMap(Map<String, dynamic> map) => Alarm(
        id: map['id'],
        hour: map['hour'],
        minute: map['minute'],
        enabled: map['enabled'],
      );

  static String encodeList(List<Alarm> alarms) =>
      jsonEncode(alarms.map((a) => a.toMap()).toList());

  static List<Alarm> decodeList(String raw) =>
      (jsonDecode(raw) as List).map((e) => Alarm.fromMap(e)).toList();
}
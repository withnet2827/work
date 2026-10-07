/// 폰 캘린더에 넣을 수 있는 일정 파일(.ics) 생성. 앱이 꺼져 있어도 캘린더 앱이 알림을 준다.
String _esc(String v) => v
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll('\r\n', r'\n')
    .replaceAll('\n', r'\n');

String _two(int n) => n.toString().padLeft(2, '0');

String _dateOnly(DateTime d) => '${d.year}${_two(d.month)}${_two(d.day)}';

String _local(DateTime d) =>
    '${_dateOnly(d)}T${_two(d.hour)}${_two(d.minute)}00';

/// [date]는 yyyy-mm-dd, [time]은 HH:mm(없으면 종일 일정).
/// 시간이 있으면 1시간 일정 + 하루 전·1시간 전 알림, 종일이면 하루 전 알림.
String buildIcs({
  required String title,
  required String date,
  String time = '',
  String description = '',
  String location = '',
  required String uid,
  DateTime? now,
}) {
  final d = DateTime.tryParse(date);
  if (d == null) throw ArgumentError('날짜 형식이 올바르지 않습니다: $date');
  final stamp = now ?? DateTime.now().toUtc();
  final dtstamp =
      '${_dateOnly(stamp)}T${_two(stamp.hour)}${_two(stamp.minute)}${_two(stamp.second)}Z';
  final tp = time.split(':');
  final hasTime =
      tp.length == 2 &&
      int.tryParse(tp[0]) != null &&
      int.tryParse(tp[1]) != null;

  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Chio Daily//KO',
    'CALSCALE:GREGORIAN',
    'BEGIN:VEVENT',
    'UID:$uid@chio-daily',
    'DTSTAMP:$dtstamp',
  ];
  if (hasTime) {
    final start = DateTime(
      d.year,
      d.month,
      d.day,
      int.parse(tp[0]),
      int.parse(tp[1]),
    );
    lines
      ..add('DTSTART:${_local(start)}')
      ..add('DTEND:${_local(start.add(const Duration(hours: 1)))}');
  } else {
    lines
      ..add('DTSTART;VALUE=DATE:${_dateOnly(d)}')
      ..add('DTEND;VALUE=DATE:${_dateOnly(d.add(const Duration(days: 1)))}');
  }
  lines.add('SUMMARY:${_esc(title)}');
  if (description.isNotEmpty) lines.add('DESCRIPTION:${_esc(description)}');
  if (location.isNotEmpty) lines.add('LOCATION:${_esc(location)}');
  void alarm(String trigger, String text) => lines
    ..add('BEGIN:VALARM')
    ..add('ACTION:DISPLAY')
    ..add('DESCRIPTION:${_esc(text)}')
    ..add('TRIGGER:$trigger')
    ..add('END:VALARM');
  alarm('-P1D', '내일: $title');
  if (hasTime) alarm('-PT1H', '1시간 후: $title');
  lines
    ..add('END:VEVENT')
    ..add('END:VCALENDAR');
  return '${lines.join('\r\n')}\r\n';
}

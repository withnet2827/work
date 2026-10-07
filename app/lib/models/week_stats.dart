import 'diary_entry.dart';

/// 하루치 산책 집계.
class DayStat {
  const DayStat({
    required this.date,
    required this.walks,
    required this.minutes,
  });
  final String date; // yyyy-mm-dd
  final int walks;
  final int minutes;
}

/// 최근 7일(오늘 포함) 일기 기록 요약.
class WeekStats {
  const WeekStats({
    required this.days,
    required this.walkCount,
    required this.walkMinutes,
    required this.poopNormal,
    required this.poopAbnormal,
    required this.poopNone,
    required this.feedCount,
  });

  final List<DayStat> days; // 오래된 날 → 오늘
  final int walkCount;
  final int walkMinutes;
  final int poopNormal; // 정상
  final int poopAbnormal; // 무름·설사·딱딱함
  final int poopNone; // 없음
  final int feedCount;

  bool get isEmpty => walkCount == 0 && feedCount == 0;
  int get maxMinutes => days.fold(0, (m, d) => d.minutes > m ? d.minutes : m);

  static const abnormalPoop = {'무름', '설사', '딱딱함'};

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory WeekStats.from(List<DiaryEntry> entries, DateTime today) {
    final base = DateTime(today.year, today.month, today.day);
    final dates = [
      for (var i = 6; i >= 0; i--) _ymd(base.subtract(Duration(days: i))),
    ];
    final perDay = {
      for (final d in dates) d: [0, 0],
    }; // [횟수, 분]
    var normal = 0, abnormal = 0, none = 0, feeds = 0;
    for (final e in entries) {
      if (!perDay.containsKey(e.date)) continue;
      feeds += e.feeds.length;
      for (final w in e.walks) {
        perDay[e.date]![0] += 1;
        perDay[e.date]![1] += w.minutes;
        if (w.poop == '정상') {
          normal++;
        } else if (abnormalPoop.contains(w.poop)) {
          abnormal++;
        } else if (w.poop == '없음') {
          none++;
        }
      }
    }
    final days = [
      for (final d in dates)
        DayStat(date: d, walks: perDay[d]![0], minutes: perDay[d]![1]),
    ];
    return WeekStats(
      days: days,
      walkCount: days.fold(0, (a, d) => a + d.walks),
      walkMinutes: days.fold(0, (a, d) => a + d.minutes),
      poopNormal: normal,
      poopAbnormal: abnormal,
      poopNone: none,
      feedCount: feeds,
    );
  }
}

/// 예방접종·예방약 기록 1건.
class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.kind,
    required this.date,
    this.name = '',
    this.nextDate = '',
    this.place = '',
    this.memo = '',
    this.author = '',
    this.createdAt = 0,
  });

  static const vaccineKinds = ['종합백신', '켄넬코프', '광견병', '코로나'];
  static const preventiveKinds = ['심장사상충', '외부 기생충', '내부 기생충'];
  static const kinds = [...vaccineKinds, ...preventiveKinds, '기타'];

  /// 종류별 일반적인 다음 일정 간격(일). 병원 안내가 우선이며 참고용 제안값이다.
  static const intervalDays = {
    '종합백신': 365,
    '켄넬코프': 365,
    '광견병': 365,
    '코로나': 365,
    '심장사상충': 30,
    '외부 기생충': 30,
    '내부 기생충': 90,
  };

  final String id;
  final String kind;
  final String name; // 예) 5종 2차, 넥스가드
  final String date; // 접종·투약한 날 yyyy-mm-dd
  final String nextDate; // 다음 예정일
  final String place;
  final String memo;
  final String author;
  final int createdAt;

  String get title => name.isEmpty ? kind : '$kind · $name';

  /// 같은 종류+이름끼리 하나의 흐름으로 본다.
  String get groupKey => '$kind|$name';

  HealthRecord copyWith({
    String? kind,
    String? name,
    String? date,
    String? nextDate,
    String? place,
    String? memo,
  }) => HealthRecord(
    id: id,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    date: date ?? this.date,
    nextDate: nextDate ?? this.nextDate,
    place: place ?? this.place,
    memo: memo ?? this.memo,
    author: author,
    createdAt: createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'kind': kind,
    'name': name,
    'date': date,
    'nextDate': nextDate,
    'place': place,
    'memo': memo,
    'author': author,
    'createdAt': createdAt,
  };

  factory HealthRecord.fromMap(Map<String, dynamic> m) => HealthRecord(
    id: m['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
    kind: m['kind'] as String? ?? '기타',
    name: m['name'] as String? ?? '',
    date: m['date'] as String? ?? '',
    nextDate: m['nextDate'] as String? ?? '',
    place: m['place'] as String? ?? '',
    memo: m['memo'] as String? ?? '',
    author: m['author'] as String? ?? '',
    createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
  );

  /// 종류별 권장 간격을 더한 다음 예정일 제안. 간격을 모르면 빈 문자열.
  static String suggestNext(String kind, String date) {
    final d = DateTime.tryParse(date);
    final days = intervalDays[kind];
    if (d == null || days == null) return '';
    final n = DateTime(d.year, d.month, d.day).add(Duration(days: days));
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// 종류+이름별 가장 최근 기록만 추려서 날짜 내림차순으로.
  static List<HealthRecord> latestPerGroup(List<HealthRecord> all) {
    final map = <String, HealthRecord>{};
    for (final r in all) {
      final cur = map[r.groupKey];
      if (cur == null || r.date.compareTo(cur.date) > 0) map[r.groupKey] = r;
    }
    return map.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  /// 다음 예정일이 [withinDays]일 이내이거나 이미 지난(미이행) 항목. 급한 순서(오래된 예정일 먼저).
  static List<HealthRecord> due(
    List<HealthRecord> all,
    DateTime today, {
    int withinDays = 30,
  }) {
    final limit = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(Duration(days: withinDays));
    final out = latestPerGroup(all).where((r) {
      final n = DateTime.tryParse(r.nextDate);
      return n != null && !n.isAfter(limit);
    }).toList()..sort((a, b) => a.nextDate.compareTo(b.nextDate));
    return out;
  }
}

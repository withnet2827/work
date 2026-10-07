/// 체중 기록 1건.
class WeightLog {
  const WeightLog({
    required this.id,
    required this.date,
    required this.kg,
    this.memo = '',
    this.author = '',
    this.createdAt = 0,
  });

  final String id;
  final String date; // yyyy-mm-dd
  final double kg;
  final String memo;
  final String author;
  final int createdAt;

  WeightLog copyWith({String? date, double? kg, String? memo}) => WeightLog(
    id: id,
    date: date ?? this.date,
    kg: kg ?? this.kg,
    memo: memo ?? this.memo,
    author: author,
    createdAt: createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date,
    'kg': kg,
    'memo': memo,
    'author': author,
    'createdAt': createdAt,
  };

  factory WeightLog.fromMap(Map<String, dynamic> m) => WeightLog(
    id: m['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
    date: m['date'] as String? ?? '',
    kg: (m['kg'] as num?)?.toDouble() ?? 0,
    memo: m['memo'] as String? ?? '',
    author: m['author'] as String? ?? '',
    createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
  );

  /// 최신 기록 대비 직전 기록의 변화량(kg). 기록이 2개 미만이면 null. 목록은 날짜 오름차순.
  static double? latestChange(List<WeightLog> asc) {
    if (asc.length < 2) return null;
    return double.parse(
      (asc.last.kg - asc[asc.length - 2].kg).toStringAsFixed(2),
    );
  }

  /// kg 표시: 불필요한 0 제거(5.0 → 5, 5.25 → 5.25).
  static String fmt(double kg) {
    final s = kg.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

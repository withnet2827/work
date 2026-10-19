/// 배변(대변) 기록 1건. 참고용 기록이며 진단이 아니다.
class StoolLog {
  const StoolLog({
    required this.id,
    required this.date,
    this.score = 3,
    this.color = '갈색',
    this.flags = const [],
    this.memo = '',
    this.photo = '',
    this.author = '',
    this.createdAt = 0,
  });

  /// 굳기 점수 1~7(2~3이 이상적).
  static const scoreLabels = {
    1: '아주 딱딱해요(알갱이)',
    2: '단단하고 촉촉해요(좋아요)',
    3: '통나무 모양이에요(좋아요)',
    4: '부드럽지만 모양이 있어요',
    5: '질어서 퍼져요',
    6: '죽처럼 퍼져요(설사)',
    7: '물 같은 설사',
  };
  static const colors = ['갈색', '주황·노랑', '녹색', '회색·흰색', '붉은 피', '검은색'];
  static const flagOptions = ['점액', '이물질', '기생충', '냄새 심함'];

  final String id;
  final String date; // yyyy-mm-dd
  final int score;
  final String color;
  final List<String> flags;
  final String memo;
  final String photo; // 작게 압축한 base64
  final String author;
  final int createdAt;

  /// 병원 상담을 고려할 만한 기록인가(점수 1·6·7, 붉은 피·검은색·회색, 기생충·이물질).
  bool get needsAttention =>
      score <= 1 ||
      score >= 6 ||
      color == '붉은 피' ||
      color == '검은색' ||
      color == '회색·흰색' ||
      flags.contains('기생충') ||
      flags.contains('이물질');

  /// 바로 진료를 권할 만한 신호(검은색 변, 붉은 피).
  bool get urgent => color == '붉은 피' || color == '검은색';

  StoolLog copyWith({
    String? date,
    int? score,
    String? color,
    List<String>? flags,
    String? memo,
    String? photo,
  }) => StoolLog(
    id: id,
    date: date ?? this.date,
    score: score ?? this.score,
    color: color ?? this.color,
    flags: flags ?? this.flags,
    memo: memo ?? this.memo,
    photo: photo ?? this.photo,
    author: author,
    createdAt: createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date,
    'score': score,
    'color': color,
    'flags': flags,
    'memo': memo,
    'photo': photo,
    'author': author,
    'createdAt': createdAt,
  };

  factory StoolLog.fromMap(Map<String, dynamic> m) => StoolLog(
    id: m['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
    date: m['date'] as String? ?? '',
    score: ((m['score'] as num?)?.toInt() ?? 3).clamp(1, 7),
    color: m['color'] as String? ?? '갈색',
    flags: [for (final f in (m['flags'] as List? ?? const [])) '$f'],
    memo: m['memo'] as String? ?? '',
    photo: m['photo'] as String? ?? '',
    author: m['author'] as String? ?? '',
    createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
  );

  /// [today] 기준 최근 [days]일(오늘 포함) 안에서 주의가 필요한 기록들.
  static List<StoolLog> recentAttention(
    List<StoolLog> all,
    String today, {
    int days = 3,
  }) {
    final t = DateTime.tryParse(today);
    if (t == null) return const [];
    final from = DateTime(t.year, t.month, t.day - (days - 1));
    final fromStr =
        '${from.year.toString().padLeft(4, '0')}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    return [
      for (final s in all)
        if (s.needsAttention &&
            s.date.compareTo(fromStr) >= 0 &&
            s.date.compareTo(today) <= 0)
          s,
    ];
  }
}

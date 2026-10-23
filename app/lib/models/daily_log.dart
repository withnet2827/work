/// 하루 산책 1회.
class WalkLog {
  const WalkLog({
    this.time = '',
    this.place = '',
    this.minutes = 0,
    this.poop = '',
    this.memo = '',
    this.photo = '',
    this.ai = '',
    this.stoolId = '',
    this.stoolScore = 0,
    this.stoolColor = '',
    this.stoolFlags = const [],
  });

  static const poopOptions = ['없음', '정상', '무름', '설사', '딱딱함', '기타'];

  final String time; // HH:mm
  final String place;
  final int minutes;
  final String poop;
  final String memo;
  final String photo; // 배변 사진(작게 압축한 base64)
  final String ai; // AI 참고 의견 한 줄
  final String stoolId; // 건강 탭 배변 기록과 연결되는 ID(없으면 빈 문자열)
  final int stoolScore; // 굳기 점수 1~7(0이면 미입력)
  final String stoolColor;
  final List<String> stoolFlags;

  /// 배변 점수를 산책 기록의 배변 표시(정상·무름·설사 등)로 바꾼다.
  static String poopFromScore(int score) {
    if (score >= 6) return '설사';
    if (score == 5) return '무름';
    if (score <= 1) return '딱딱함';
    return '정상';
  }

  String get summary => [
    if (time.isNotEmpty) time,
    if (place.isNotEmpty) place,
    if (minutes > 0) '$minutes분',
    if (poop.isNotEmpty) '배변 $poop',
  ].join(' · ');

  Map<String, dynamic> toMap() => {
    'time': time,
    'place': place,
    'minutes': minutes,
    'poop': poop,
    'memo': memo,
    'photo': photo,
    'ai': ai,
    'stoolId': stoolId,
    'stoolScore': stoolScore,
    'stoolColor': stoolColor,
    'stoolFlags': stoolFlags,
  };

  factory WalkLog.fromMap(Map<String, dynamic> m) => WalkLog(
    time: m['time'] as String? ?? '',
    place: m['place'] as String? ?? '',
    minutes: (m['minutes'] as num?)?.toInt() ?? 0,
    poop: m['poop'] as String? ?? '',
    memo: m['memo'] as String? ?? '',
    photo: m['photo'] as String? ?? '',
    ai: m['ai'] as String? ?? '',
    stoolId: m['stoolId'] as String? ?? '',
    stoolScore: (m['stoolScore'] as num?)?.toInt() ?? 0,
    stoolColor: m['stoolColor'] as String? ?? '',
    stoolFlags: [for (final f in (m['stoolFlags'] as List? ?? const [])) '$f'],
  );
}

/// 기본 급여 외 추가 급여(간식·영양제 등) 1건.
class FeedLog {
  const FeedLog({
    this.time = '',
    this.kind = '',
    this.amount = '',
    this.memo = '',
    this.photo = '',
  });

  static const kindSuggestions = ['간식', '영양제', '사료 추가', '과일', '뼈·껌'];

  final String time; // HH:mm
  final String kind;
  final String amount; // 예) 3개, 한 스푼, 20g
  final String memo;
  final String photo; // 사진(작게 압축한 base64, 없으면 빈 문자열)

  String get summary => [
    if (time.isNotEmpty) time,
    if (kind.isNotEmpty) kind,
    if (amount.isNotEmpty) amount,
  ].join(' · ');

  Map<String, dynamic> toMap() => {
    'time': time,
    'kind': kind,
    'amount': amount,
    'memo': memo,
    'photo': photo,
  };

  factory FeedLog.fromMap(Map<String, dynamic> m) => FeedLog(
    time: m['time'] as String? ?? '',
    kind: m['kind'] as String? ?? '',
    amount: m['amount'] as String? ?? '',
    memo: m['memo'] as String? ?? '',
    photo: m['photo'] as String? ?? '',
  );
}

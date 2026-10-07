/// 하루 산책 1회.
class WalkLog {
  const WalkLog({
    this.time = '',
    this.place = '',
    this.minutes = 0,
    this.poop = '',
    this.memo = '',
  });

  static const poopOptions = ['없음', '정상', '무름', '설사', '딱딱함', '기타'];

  final String time; // HH:mm
  final String place;
  final int minutes;
  final String poop;
  final String memo;

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
  };

  factory WalkLog.fromMap(Map<String, dynamic> m) => WalkLog(
    time: m['time'] as String? ?? '',
    place: m['place'] as String? ?? '',
    minutes: (m['minutes'] as num?)?.toInt() ?? 0,
    poop: m['poop'] as String? ?? '',
    memo: m['memo'] as String? ?? '',
  );
}

/// 기본 급여 외 추가 급여(간식·영양제 등) 1건.
class FeedLog {
  const FeedLog({
    this.time = '',
    this.kind = '',
    this.amount = '',
    this.memo = '',
  });

  static const kindSuggestions = ['간식', '영양제', '사료 추가', '과일', '뼈·껌'];

  final String time; // HH:mm
  final String kind;
  final String amount; // 예) 3개, 한 스푼, 20g
  final String memo;

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
  };

  factory FeedLog.fromMap(Map<String, dynamic> m) => FeedLog(
    time: m['time'] as String? ?? '',
    kind: m['kind'] as String? ?? '',
    amount: m['amount'] as String? ?? '',
    memo: m['memo'] as String? ?? '',
  );
}

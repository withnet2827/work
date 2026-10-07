import 'attachment.dart';

/// 병원·미용 등 방문(예약) 기록 1건.
class Visit {
  const Visit({
    required this.id,
    this.type = '병원',
    this.status = '완료',
    this.date = '',
    this.time = '',
    this.placeId = '',
    this.placeName = '',
    this.amount = 0,
    this.detail = '',
    this.prescription = '',
    this.memo = '',
    this.nextDate = '',
    this.author = '',
    this.createdAt = 0,
    this.photoCount = 0,
    this.photos = const [],
  });

  static const types = ['병원', '미용', '기타'];
  static const statuses = ['예약', '완료'];

  final String id;
  final String type;
  final String status; // 예약 | 완료
  final String date; // yyyy-mm-dd
  final String time; // HH:mm (선택)
  final String placeId;
  final String placeName;
  final int amount; // 원
  final String detail; // 병원: 증상·진단 / 미용: 시술 내용
  final String prescription; // 병원: 처방·처치
  final String memo;
  final String nextDate; // 다음 예약 yyyy-mm-dd (선택)
  final String author;
  final int createdAt;
  final int photoCount;
  final List<Attachment> photos; // 목록 조회에서는 비어 있고, 상세에서 불러온다

  bool get isUpcoming => status == '예약';

  Visit copyWith({
    String? type,
    String? status,
    String? date,
    String? time,
    String? placeId,
    String? placeName,
    int? amount,
    String? detail,
    String? prescription,
    String? memo,
    String? nextDate,
    List<Attachment>? photos,
  }) => Visit(
    id: id,
    type: type ?? this.type,
    status: status ?? this.status,
    date: date ?? this.date,
    time: time ?? this.time,
    placeId: placeId ?? this.placeId,
    placeName: placeName ?? this.placeName,
    amount: amount ?? this.amount,
    detail: detail ?? this.detail,
    prescription: prescription ?? this.prescription,
    memo: memo ?? this.memo,
    nextDate: nextDate ?? this.nextDate,
    author: author,
    createdAt: createdAt,
    photoCount: photos?.length ?? photoCount,
    photos: photos ?? this.photos,
  );

  /// 사진 제외 정보(서버 문서용)
  Map<String, dynamic> toMeta() => {
    'type': type,
    'status': status,
    'date': date,
    'time': time,
    'placeId': placeId,
    'placeName': placeName,
    'amount': amount,
    'detail': detail,
    'prescription': prescription,
    'memo': memo,
    'nextDate': nextDate,
    'author': author,
    'createdAt': createdAt,
    'photoCount': photoCount,
  };

  Map<String, dynamic> toMap() => {
    'id': id,
    ...toMeta(),
    'photos': photos.map((e) => e.toMap()).toList(),
  };

  factory Visit.fromMap(
    Map<String, dynamic> m, {
    String? id,
    List<Attachment>? photos,
  }) {
    final ph =
        photos ??
        [
          for (final e in (m['photos'] as List? ?? const []))
            Attachment.fromMap(Map<String, dynamic>.from(e as Map)),
        ];
    return Visit(
      id:
          id ??
          m['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      type: m['type'] as String? ?? '병원',
      status: m['status'] as String? ?? '완료',
      date: m['date'] as String? ?? '',
      time: m['time'] as String? ?? '',
      placeId: m['placeId'] as String? ?? '',
      placeName: m['placeName'] as String? ?? '',
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      detail: m['detail'] as String? ?? '',
      prescription: m['prescription'] as String? ?? '',
      memo: m['memo'] as String? ?? '',
      nextDate: m['nextDate'] as String? ?? '',
      author: m['author'] as String? ?? '',
      createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
      photoCount: (m['photoCount'] as num?)?.toInt() ?? ph.length,
      photos: ph,
    );
  }
}

/// 예약 중인 방문을 가까운 날짜순으로.
List<Visit> upcomingVisits(List<Visit> all, String today) {
  final list =
      all.where((v) => v.isUpcoming && v.date.compareTo(today) >= 0).toList()
        ..sort(
          (a, b) => ('${a.date} ${a.time}').compareTo('${b.date} ${b.time}'),
        );
  return list;
}

/// 오늘 기준 D-day 문구. 날짜 형식이 잘못되면 빈 문자열.
String ddayText(String date, DateTime today) {
  final d = DateTime.tryParse(date);
  if (d == null) return '';
  final diff = DateTime(
    d.year,
    d.month,
    d.day,
  ).difference(DateTime(today.year, today.month, today.day)).inDays;
  if (diff == 0) return 'D-day';
  return diff > 0 ? 'D-$diff' : 'D+${-diff}';
}

/// 치오와 관련된 장소(병원, 미용실 등). 주소는 지도 앱 검색에 사용한다.
class Place {
  const Place({
    required this.id,
    this.category = '병원',
    this.name = '',
    this.phone = '',
    this.address = '',
    this.memo = '',
  });

  static const categories = ['병원', '미용실', '약국', '펫호텔·유치원', '용품점', '기타'];

  final String id;
  final String category;
  final String name;
  final String phone;
  final String address;
  final String memo;

  /// 지도 검색어: 주소가 있으면 주소, 없으면 이름.
  String get mapQuery => address.isNotEmpty ? address : name;

  Place copyWith({String? category, String? name, String? phone, String? address, String? memo}) =>
      Place(
        id: id,
        category: category ?? this.category,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        memo: memo ?? this.memo,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'category': category,
        'name': name,
        'phone': phone,
        'address': address,
        'memo': memo,
      };

  factory Place.fromMap(Map<String, dynamic> m) => Place(
        id: m['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        category: m['category'] as String? ?? '기타',
        name: m['name'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        address: m['address'] as String? ?? '',
        memo: m['memo'] as String? ?? '',
      );
}

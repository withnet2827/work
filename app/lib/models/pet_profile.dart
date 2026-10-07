import 'dart:convert';

import 'place.dart';

/// 반려견 프로필. 1단계에서는 단말 로컬에 저장하고, 이후 Firestore로 교체한다.
class PetProfile {
  const PetProfile({
    this.name = '치오',
    this.gender = '',
    this.neutered = false,
    this.birthDate = '',
    this.adoptionDate = '',
    this.breed = '',
    this.registrationNo = '',
    this.allergies = '',
    this.notes = '',
    this.photoBase64 = '',
    this.places = const [],
  });

  final String name;
  final String gender;
  final bool neutered;
  final String birthDate; // yyyy-mm-dd
  final String adoptionDate; // yyyy-mm-dd
  final String breed;
  final String registrationNo;
  final String allergies;
  final String notes;
  final String photoBase64; // 대표 사진(축소본). 드라이브 연동 후 파일 ID로 교체 예정
  final List<Place> places;

  PetProfile copyWith({
    String? name,
    String? gender,
    bool? neutered,
    String? birthDate,
    String? adoptionDate,
    String? breed,
    String? registrationNo,
    String? allergies,
    String? notes,
    String? photoBase64,
    List<Place>? places,
  }) =>
      PetProfile(
        name: name ?? this.name,
        gender: gender ?? this.gender,
        neutered: neutered ?? this.neutered,
        birthDate: birthDate ?? this.birthDate,
        adoptionDate: adoptionDate ?? this.adoptionDate,
        breed: breed ?? this.breed,
        registrationNo: registrationNo ?? this.registrationNo,
        allergies: allergies ?? this.allergies,
        notes: notes ?? this.notes,
        photoBase64: photoBase64 ?? this.photoBase64,
        places: places ?? this.places,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'gender': gender,
        'neutered': neutered,
        'birthDate': birthDate,
        'adoptionDate': adoptionDate,
        'breed': breed,
        'registrationNo': registrationNo,
        'allergies': allergies,
        'notes': notes,
        'photoBase64': photoBase64,
        'places': places.map((e) => e.toMap()).toList(),
      };

  factory PetProfile.fromMap(Map<String, dynamic> m) {
    final places = <Place>[
      for (final e in (m['places'] as List? ?? const []))
        Place.fromMap(Map<String, dynamic>.from(e as Map)),
    ];
    // 이전 버전(병원·미용실 고정 필드) 데이터 이전
    void legacy(String category, String? name, String? phone) {
      if ((name ?? '').isEmpty && (phone ?? '').isEmpty) return;
      places.add(Place(
        id: 'legacy-$category',
        category: category,
        name: name ?? '',
        phone: phone ?? '',
      ));
    }

    if (m['places'] == null) {
      legacy('병원', m['clinicName'] as String?, m['clinicPhone'] as String?);
      legacy('미용실', m['groomerName'] as String?, m['groomerPhone'] as String?);
    }
    return PetProfile(
      name: m['name'] as String? ?? '치오',
      gender: m['gender'] as String? ?? '',
      neutered: m['neutered'] as bool? ?? false,
      birthDate: m['birthDate'] as String? ?? '',
      adoptionDate: m['adoptionDate'] as String? ?? '',
      breed: m['breed'] as String? ?? '',
      registrationNo: m['registrationNo'] as String? ?? '',
      allergies: m['allergies'] as String? ?? '',
      notes: m['notes'] as String? ?? '',
      photoBase64: m['photoBase64'] as String? ?? '',
      places: places,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory PetProfile.fromJson(String s) =>
      PetProfile.fromMap(jsonDecode(s) as Map<String, dynamic>);

  /// 생일 기준 만 나이 문구. 생일이 없으면 빈 문자열.
  String ageText([DateTime? now]) {
    final b = DateTime.tryParse(birthDate);
    if (b == null) return '';
    final n = now ?? DateTime.now();
    var months = (n.year - b.year) * 12 + n.month - b.month;
    if (n.day < b.day) months--;
    if (months < 0) return '';
    final y = months ~/ 12;
    final m = months % 12;
    return y > 0 ? '$y살 $m개월' : '$m개월';
  }

  /// 입양일로부터 함께한 날수(입양 당일 = 1일).
  int? daysTogether([DateTime? now]) {
    final a = DateTime.tryParse(adoptionDate);
    if (a == null) return null;
    final n = now ?? DateTime.now();
    final d = DateTime(n.year, n.month, n.day).difference(DateTime(a.year, a.month, a.day)).inDays;
    return d < 0 ? null : d + 1;
  }
}

import 'dart:convert';

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
    this.clinicName = '',
    this.clinicPhone = '',
    this.groomerName = '',
    this.groomerPhone = '',
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
  final String clinicName;
  final String clinicPhone;
  final String groomerName;
  final String groomerPhone;

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
    String? clinicName,
    String? clinicPhone,
    String? groomerName,
    String? groomerPhone,
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
        clinicName: clinicName ?? this.clinicName,
        clinicPhone: clinicPhone ?? this.clinicPhone,
        groomerName: groomerName ?? this.groomerName,
        groomerPhone: groomerPhone ?? this.groomerPhone,
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
        'clinicName': clinicName,
        'clinicPhone': clinicPhone,
        'groomerName': groomerName,
        'groomerPhone': groomerPhone,
      };

  factory PetProfile.fromMap(Map<String, dynamic> m) => PetProfile(
        name: m['name'] as String? ?? '치오',
        gender: m['gender'] as String? ?? '',
        neutered: m['neutered'] as bool? ?? false,
        birthDate: m['birthDate'] as String? ?? '',
        adoptionDate: m['adoptionDate'] as String? ?? '',
        breed: m['breed'] as String? ?? '',
        registrationNo: m['registrationNo'] as String? ?? '',
        allergies: m['allergies'] as String? ?? '',
        notes: m['notes'] as String? ?? '',
        clinicName: m['clinicName'] as String? ?? '',
        clinicPhone: m['clinicPhone'] as String? ?? '',
        groomerName: m['groomerName'] as String? ?? '',
        groomerPhone: m['groomerPhone'] as String? ?? '',
      );

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

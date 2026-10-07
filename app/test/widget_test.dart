import 'package:flutter/material.dart';
import 'package:chio_daily/data/profile_store.dart';
import 'package:chio_daily/main.dart';
import 'package:chio_daily/models/pet_profile.dart';
import 'package:chio_daily/models/place.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('나이와 함께한 날수 계산', () {
    const p = PetProfile(birthDate: '2022-03-15', adoptionDate: '2022-05-01');
    expect(p.ageText(DateTime(2026, 10, 7)), '4살 6개월');
    expect(p.daysTogether(DateTime(2022, 5, 1)), 1);
    expect(const PetProfile().ageText(), '');
  });

  test('JSON 저장 왕복(장소 포함)', () {
    const p = PetProfile(
      name: '치오',
      registrationNo: '410123456789012',
      neutered: true,
      places: [Place(id: '1', category: '병원', name: '행복동물병원', address: '서울 강남구', memo: '야간 진료')],
    );
    final r = PetProfile.fromJson(p.toJson());
    expect(r.registrationNo, p.registrationNo);
    expect(r.places.single.memo, '야간 진료');
    expect(r.places.single.mapQuery, '서울 강남구');
  });

  test('이전 버전 병원·미용실 필드 이전', () {
    final r = PetProfile.fromMap({
      'name': '치오',
      'clinicName': '옛병원',
      'clinicPhone': '02-1',
      'groomerName': '옛미용실',
    });
    expect(r.places.map((e) => e.category), ['병원', '미용실']);
    expect(r.places.first.name, '옛병원');
  });

  testWidgets('프로필 탭에서 장소 추가', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ChioApp(store: LocalProfileStore()));
    await tester.pumpAndSettle();
    expect(find.text('치오 데일리'), findsOneWidget);
    await tester.tap(find.text('프로필'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('추가'), 300);
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '행복동물병원');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('행복동물병원'), 300);
    expect(find.text('행복동물병원'), findsOneWidget);
  });
}

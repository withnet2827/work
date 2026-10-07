import 'package:flutter/material.dart';
import 'package:chio_daily/data/profile_store.dart';
import 'package:chio_daily/main.dart';
import 'package:chio_daily/models/attachment.dart';
import 'package:chio_daily/models/diary_entry.dart';
import 'package:chio_daily/data/diary_store.dart';
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
      places: [
        Place(
          id: '1',
          category: '병원',
          name: '행복동물병원',
          address: '서울 강남구',
          memo: '야간 진료',
        ),
      ],
    );
    final r = PetProfile.fromJson(p.toJson());
    expect(r.registrationNo, p.registrationNo);
    expect(r.places.single.memo, '야간 진료');
    expect(r.places.single.mapQuery, '서울 강남구');
  });

  test('장소 첨부 사진 저장 왕복', () {
    const p = PetProfile(
      places: [
        Place(
          id: '1',
          name: '미용실',
          attachments: [
            Attachment(
              id: 'a',
              photoBase64: 'AAAA',
              label: '미용 전',
              date: '2026-10-07',
            ),
          ],
        ),
      ],
    );
    final r = PetProfile.fromJson(p.toJson());
    expect(r.places.single.attachments.single.label, '미용 전');
    expect(r.places.single.attachments.single.date, '2026-10-07');
  });

  test('일기 저장·정렬·삭제(로컬)', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalDiaryStore();
    await store.save(
      const DiaryEntry(
        id: 'a',
        date: '2026-10-01',
        body: '첫째',
        photos: ['AAAA'],
      ),
    );
    await store.save(
      const DiaryEntry(id: 'b', date: '2026-10-05', body: '둘째', mood: '😊'),
    );
    var list = await store.load();
    expect(list.map((e) => e.id), ['b', 'a']);
    expect(list.last.photos, ['AAAA']);
    await store.save(list.first.copyWith(body: '수정'));
    await store.delete('a');
    list = await store.load();
    expect(list.single.body, '수정');
  });

  testWidgets('일기 탭에서 일기 쓰기', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ChioApp(store: LocalProfileStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('일기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('아직 일기가 없어요'), findsOneWidget);
    await tester.tap(find.text('일기 쓰기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '오늘 공원 산책!');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('오늘 공원 산책!'), findsOneWidget);
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

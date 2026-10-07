import 'package:chio_daily/data/profile_store.dart';
import 'package:chio_daily/main.dart';
import 'package:chio_daily/models/pet_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('나이와 함께한 날수 계산', () {
    const p = PetProfile(birthDate: '2022-03-15', adoptionDate: '2022-05-01');
    expect(p.ageText(DateTime(2026, 10, 7)), '4살 6개월');
    expect(p.daysTogether(DateTime(2022, 5, 1)), 1);
    expect(const PetProfile().ageText(), '');
  });

  test('JSON 저장 왕복', () {
    const p = PetProfile(name: '치오', registrationNo: '410123456789012', neutered: true);
    final r = PetProfile.fromJson(p.toJson());
    expect(r.registrationNo, p.registrationNo);
    expect(r.neutered, isTrue);
  });

  testWidgets('앱 실행 시 홈과 프로필 탭 표시', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ChioApp(store: LocalProfileStore()));
    await tester.pumpAndSettle();
    expect(find.text('치오 데일리'), findsOneWidget);
    await tester.tap(find.text('프로필'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('프로필 수정'), 300);
    expect(find.text('프로필 수정'), findsOneWidget);
  });
}

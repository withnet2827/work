import 'package:flutter/material.dart';
import 'package:chio_daily/data/profile_store.dart';
import 'package:chio_daily/main.dart';
import 'package:chio_daily/models/attachment.dart';
import 'package:chio_daily/models/visit.dart';
import 'package:chio_daily/data/visit_store.dart';
import 'package:chio_daily/models/diary_entry.dart';
import 'package:chio_daily/data/diary_store.dart';
import 'package:chio_daily/models/diary_comment.dart';
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

  test('일기 댓글·공감 저장과 집계(로컬)', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalDiaryStore();
    await store.save(const DiaryEntry(id: 'a', date: '2026-10-01', body: '첫째'));
    await store.addComment(
      'a',
      const DiaryComment(
        id: 'c1',
        author: '엄마',
        authorId: 'u1',
        text: '귀여워',
        createdAt: 1,
      ),
    );
    await store.addComment(
      'a',
      const DiaryComment(
        id: 'c2',
        author: '아빠',
        authorId: 'u2',
        text: '최고',
        createdAt: 2,
      ),
    );
    await store.setReaction('a', 'u1', '엄마', '❤️');
    await store.setReaction('a', 'u2', '아빠', '👍');
    await store.setReaction('a', 'u2', '아빠', '❤️'); // 구성원당 1개: 바꾸면 교체
    var e = (await store.load()).single;
    expect(e.commentCount, 2);
    expect(e.reactionCount, 2);
    expect((await store.loadComments('a')).map((c) => c.text), ['귀여워', '최고']);
    expect(
      (await store.loadReactions('a')).every((r) => r.emoji == '❤️'),
      isTrue,
    );
    await store.deleteComment('a', 'c1');
    await store.setReaction('a', 'u1', '엄마', null);
    e = (await store.load()).single;
    expect(e.commentCount, 1);
    expect(e.reactionCount, 1);
  });

  testWidgets('일기 상세에서 댓글과 공감', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ChioApp(store: LocalProfileStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('일기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('일기 쓰기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '오늘 공원 산책!');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('오늘 공원 산책!'));
    await tester.pumpAndSettle();
    expect(find.text('첫 댓글을 남겨 보세요.'), findsOneWidget);
    await tester.tap(find.textContaining('❤️'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '댓글 달기'), '정말 귀엽다');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(find.text('정말 귀엽다'), findsOneWidget);
    expect(find.text('댓글 1'), findsOneWidget);
    // 목록으로 돌아오면 집계가 보인다
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('💬 1'), findsOneWidget);
    expect(find.textContaining('❤️ 1'), findsOneWidget);
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

  test('방문 기록 저장·정렬·사진·삭제(로컬)', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalVisitStore();
    await store.save(
      const Visit(
        id: 'a',
        date: '2026-09-01',
        placeName: '행복동물병원',
        amount: 35000,
      ),
    );
    await store.save(
      Visit(
        id: 'b',
        type: '미용',
        status: '예약',
        date: '2026-10-20',
        time: '14:00',
        placeName: '멍멍미용',
        photos: const [
          Attachment(
            id: 'p',
            photoBase64: 'AAAA',
            label: '미용 전',
            date: '2026-10-20',
          ),
        ],
      ),
    );
    final list = await store.load();
    expect(list.map((e) => e.id), ['b', 'a']);
    expect((await store.loadPhotos('b')).single.label, '미용 전');
    expect(upcomingVisits(list, '2026-10-07').map((e) => e.id), ['b']);
    expect(upcomingVisits(list, '2026-10-21'), isEmpty);
    await store.delete('a');
    expect((await store.load()).length, 1);
  });

  test('D-day 문구', () {
    final today = DateTime(2026, 10, 7);
    expect(ddayText('2026-10-10', today), 'D-3');
    expect(ddayText('2026-10-07', today), 'D-day');
    expect(ddayText('2026-10-05', today), 'D+2');
    expect(ddayText('', today), '');
  });

  testWidgets('병원·미용 탭에서 기록 추가', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ChioApp(store: LocalProfileStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('병원·미용'));
    await tester.pumpAndSettle();
    expect(find.textContaining('아직 기록이 없어요'), findsOneWidget);
    await tester.tap(find.text('기록 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '장소 이름'), '행복동물병원');
    await tester.enterText(find.widgetWithText(TextField, '금액(원)'), '35000');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('행복동물병원'), findsOneWidget);
    expect(find.textContaining('35,000원'), findsWidgets);
  });

  testWidgets('방문 기록: 등록된 장소를 선택하고 다른 곳도 직접 입력', (tester) async {
    SharedPreferences.setMockInitialValues({
      'pet_profile_v1': const PetProfile(
        places: [
          Place(id: 'h1', category: '병원', name: '보듬동물병원'),
          Place(id: 'g1', category: '미용실', name: '멍멍미용'),
        ],
      ).toJson(),
    });
    await tester.pumpWidget(ChioApp(store: LocalProfileStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('병원·미용'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록 추가'));
    await tester.pumpAndSettle();
    // 병원 구분: 병원 장소만 선택지로 보인다
    expect(find.text('보듬동물병원'), findsOneWidget);
    expect(find.text('멍멍미용'), findsNothing);
    expect(find.widgetWithText(TextField, '장소 이름'), findsNothing);
    // 직접 입력을 누르면 입력칸이 열린다
    await tester.tap(find.text('다른 곳 직접 입력'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '장소 이름'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '장소 이름'), '새로운병원');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('새로운병원'), findsOneWidget);
    // 이번에는 등록된 장소 선택
    await tester.tap(find.text('기록 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('보듬동물병원'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('보듬동물병원'), findsOneWidget);
  });

  testWidgets('직접 입력한 장소를 프로필 장소로도 저장', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ChioApp(store: LocalProfileStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('병원·미용'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '장소 이름'), '새벽동물병원');
    await tester.tap(find.text('프로필 장소로도 저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    // 프로필 탭의 장소 목록에 추가되었다
    await tester.tap(find.text('프로필'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('새벽동물병원'), 300);
    expect(find.text('새벽동물병원'), findsOneWidget);
    // 다음 기록에서는 선택 버튼으로 나타난다
    await tester.tap(find.text('병원·미용'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록 추가'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, '새벽동물병원'), findsOneWidget);
  });

  testWidgets('체크하지 않으면 프로필 장소에 추가되지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ChioApp(store: LocalProfileStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('병원·미용'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '장소 이름'), '임시병원');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록 추가'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, '임시병원'), findsNothing);
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

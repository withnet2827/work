import 'package:flutter/material.dart';
import 'package:chio_daily/data/profile_store.dart';
import 'package:chio_daily/main.dart';
import 'package:chio_daily/models/attachment.dart';
import 'package:chio_daily/models/visit.dart';
import 'package:chio_daily/data/visit_store.dart';
import 'package:chio_daily/backup/backup_service.dart';

import 'dart:convert';

import 'package:chio_daily/models/diary_entry.dart';
import 'package:chio_daily/data/diary_store.dart';
import 'package:chio_daily/models/diary_comment.dart';
import 'package:chio_daily/models/daily_log.dart';
import 'package:chio_daily/models/week_stats.dart';
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

  test('CSV 칸 처리: 쉼표·따옴표·줄바꿈', () {
    expect(csvCell('보듬 동물병원'), '보듬 동물병원');
    expect(csvCell('귀, 눈'), '"귀, 눈"');
    expect(csvCell('say "hi"'), r'"say ""hi"""');
    expect(csvCell('a\nb'), '"a\nb"');
  });

  test('방문·지출 CSV 생성', () {
    final csv = visitsCsv(const [
      Visit(
        id: 'b',
        date: '2026-10-05',
        placeName: '미용실',
        type: '미용',
        amount: 40000,
      ),
      Visit(
        id: 'a',
        date: '2026-09-01',
        placeName: '병원, 본점',
        amount: 35000,
        memo: '메모',
      ),
    ]);
    expect(csv.startsWith('﻿날짜,시간,구분'), isTrue);
    final lines = csv.trim().split('\r\n');
    expect(lines.length, 3);
    expect(lines[1], contains('"병원, 본점"')); // 날짜순(오래된 것 먼저)
    expect(lines[2], contains('미용실'));
  });

  test('전체 백업 JSON 구성', () async {
    SharedPreferences.setMockInitialValues({});
    final diary = LocalDiaryStore();
    final visits = LocalVisitStore();
    await diary.save(
      const DiaryEntry(
        id: 'd1',
        date: '2026-10-01',
        body: '일기',
        photos: ['AAAA'],
      ),
    );
    await diary.addComment(
      'd1',
      const DiaryComment(
        id: 'c1',
        author: '엄마',
        authorId: 'u',
        text: '굿',
        createdAt: 1,
      ),
    );
    await visits.save(
      Visit(
        id: 'v1',
        date: '2026-10-02',
        placeName: '병원',
        amount: 1000,
        photos: const [Attachment(id: 'p', photoBase64: 'BBBB', label: '영수증')],
      ),
    );
    final out = await buildBackupJson(
      profile: const PetProfile(name: '치오'),
      diaryStore: diary,
      visitStore: visits,
      now: DateTime(2026, 10, 7),
    );
    final m = jsonDecode(out) as Map<String, dynamic>;
    expect(m['profile']['name'], '치오');
    expect((m['diary'] as List).single['photos'], ['AAAA']);
    expect((m['diary'] as List).single['comments'], isNotEmpty);
    expect((m['visits'] as List).single['photos'][0]['label'], '영수증');
    expect(
      backupFileName('x', 'json', DateTime(2026, 10, 7)),
      'x-2026-10-07.json',
    );
  });

  test('일기 산책·추가 급여 저장 왕복', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalDiaryStore();
    await store.save(
      const DiaryEntry(
        id: 'w1',
        date: '2026-10-07',
        walks: [
          WalkLog(
            time: '07:30',
            place: '한강공원',
            minutes: 30,
            poop: '정상',
            memo: '신나게 뜀',
          ),
          WalkLog(time: '19:00', place: '동네', minutes: 15, poop: '없음'),
        ],
        feeds: [FeedLog(time: '15:00', kind: '간식', amount: '3개', memo: '닭가슴살')],
      ),
    );
    final e = (await store.load()).single;
    expect(e.walks.length, 2);
    expect(e.walks.first.summary, '07:30 · 한강공원 · 30분 · 배변 정상');
    expect(e.walks.last.summary, '19:00 · 동네 · 15분 · 배변 없음');
    expect(e.feeds.single.summary, '15:00 · 간식 · 3개');
    // 서버 문서용 메타에도 포함되어야 한다
    final meta = e.toMeta();
    expect((meta['walks'] as List).length, 2);
    expect((meta['feeds'] as List).length, 1);
    // 이전 일기(산책·급여 필드 없음)도 읽힌다
    final old = DiaryEntry.fromMap({
      'id': 'o',
      'date': '2026-01-01',
      'body': '옛 일기',
    });
    expect(old.walks, isEmpty);
    expect(old.feeds, isEmpty);
  });

  testWidgets('일기 작성 화면에서 산책과 추가 급여 입력', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ChioApp(store: LocalProfileStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('일기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('일기 쓰기'));
    await tester.pumpAndSettle();
    // 산책 추가
    await tester.tap(find.text('산책 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '장소 (예: 한강공원)'),
      '한강공원',
    );
    await tester.enterText(find.widgetWithText(TextField, '산책 시간(분)'), '30');
    await tester.tap(find.text('정상'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.textContaining('한강공원 · 30분 · 배변 정상'), findsOneWidget);
    // 추가 급여
    await tester.tap(find.text('추가').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('간식'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '양 (예: 3개, 한 스푼, 20g)'),
      '3개',
    );
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.textContaining('간식 · 3개'), findsOneWidget);
    // 본문 없이도 저장되고, 목록 카드에 요약이 보인다
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.textContaining('산책 1회 (30분)'), findsOneWidget);
    expect(find.textContaining('추가 급여 1건'), findsOneWidget);
  });

  testWidgets('일기 목록에서 수정·삭제 버튼, 상세에서 삭제', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ChioApp(store: LocalProfileStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('일기'));
    await tester.pumpAndSettle();
    for (final body in ['첫 일기', '둘째 일기']) {
      await tester.tap(find.text('일기 쓰기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), body);
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
    }
    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
    // 목록 삭제: 취소하면 남고, 삭제하면 사라진다
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('둘째 일기'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();
    expect(find.text('둘째 일기'), findsNothing);
    expect(find.text('첫 일기'), findsOneWidget);
    // 상세 화면에서 삭제
    await tester.tap(find.text('첫 일기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();
    expect(find.text('첫 일기'), findsNothing);
    expect(find.textContaining('아직 일기가 없어요'), findsOneWidget);
  });

  testWidgets('홈의 다가오는 예약: 눌러서 확인·완료 처리·삭제', (tester) async {
    final today = DateTime.now();
    String d(DateTime t) =>
        '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'visits_v1': jsonEncode([
        Visit(
          id: 'u1',
          type: '미용',
          status: '예약',
          date: d(today.add(const Duration(days: 3))),
          time: '14:00',
          placeName: '멍멍미용',
          amount: 40000,
          memo: '발톱도 부탁',
          photos: const [
            Attachment(id: 'p', photoBase64: 'AAAA', label: '미용 전'),
          ],
        ).toMap(),
      ]),
    });
    await tester.pumpWidget(ChioApp(store: LocalProfileStore()));
    await tester.pumpAndSettle();
    expect(find.text('다가오는 예약'), findsOneWidget);
    await tester.tap(find.text('멍멍미용'));
    await tester.pumpAndSettle();
    // 확인 창: 내용과 세 버튼
    expect(find.text('발톱도 부탁'), findsOneWidget);
    expect(find.text('40,000원'), findsOneWidget);
    expect(find.text('수정'), findsOneWidget);
    expect(find.text('완료 처리'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);
    // 완료 처리: 다가오는 예약에서 빠지고, 사진은 그대로 남는다
    await tester.tap(find.text('완료 처리'));
    await tester.pumpAndSettle();
    expect(find.text('다가오는 예약'), findsNothing);
    final kept = await LocalVisitStore().loadPhotos('u1');
    expect(kept.single.label, '미용 전');
    expect((await LocalVisitStore().load()).single.status, '완료');
  });

  testWidgets('병원·미용 목록에서 기록 삭제', (tester) async {
    SharedPreferences.setMockInitialValues({
      'visits_v1': jsonEncode([
        const Visit(
          id: 'a',
          date: '2026-09-01',
          placeName: '보듬동물병원',
          amount: 20000,
        ).toMap(),
      ]),
    });
    await tester.pumpWidget(ChioApp(store: LocalProfileStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('병원·미용'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('보듬동물병원'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();
    expect(find.text('보듬동물병원'), findsNothing);
    expect(await LocalVisitStore().load(), isEmpty);
  });

  test('최근 7일 요약 집계', () {
    final today = DateTime(2026, 10, 7);
    final stats = WeekStats.from(const [
      DiaryEntry(
        id: 'a',
        date: '2026-10-07',
        walks: [
          WalkLog(minutes: 30, poop: '정상'),
          WalkLog(minutes: 15, poop: '없음'),
        ],
        feeds: [FeedLog(kind: '간식')],
      ),
      DiaryEntry(
        id: 'b',
        date: '2026-10-05',
        walks: [WalkLog(minutes: 20, poop: '설사')],
      ),
      // 범위 밖(7일 전보다 이전, 미래)은 제외
      DiaryEntry(
        id: 'c',
        date: '2026-09-30',
        walks: [WalkLog(minutes: 99, poop: '정상')],
      ),
      DiaryEntry(
        id: 'd',
        date: '2026-10-08',
        walks: [WalkLog(minutes: 99, poop: '정상')],
      ),
    ], today);
    expect(stats.days.length, 7);
    expect(stats.days.first.date, '2026-10-01');
    expect(stats.days.last.date, '2026-10-07');
    expect(stats.walkCount, 3);
    expect(stats.walkMinutes, 65);
    expect(stats.poopNormal, 1);
    expect(stats.poopAbnormal, 1);
    expect(stats.poopNone, 1);
    expect(stats.feedCount, 1);
    expect(stats.maxMinutes, 45);
    expect(WeekStats.from(const [], today).isEmpty, isTrue);
  });

  testWidgets('홈 요약: 일기에 쓴 산책이 반영된다', (tester) async {
    final now = DateTime.now();
    final d =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'diary_v1': jsonEncode([
        DiaryEntry(
          id: 'x',
          date: d,
          walks: const [WalkLog(minutes: 25, poop: '무름')],
        ).toMap(),
      ]),
    });
    await tester.pumpWidget(ChioApp(store: LocalProfileStore()));
    await tester.pumpAndSettle();
    expect(find.text('최근 7일'), findsOneWidget);
    expect(find.textContaining('산책 1회 · 총 25분'), findsOneWidget);
    expect(find.textContaining('이상 1'), findsOneWidget);
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

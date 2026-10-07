import 'dart:convert';

import '../data/diary_store.dart';
import '../data/record_store.dart';
import '../models/health_record.dart';
import '../models/weight_log.dart';
import '../data/visit_store.dart';
import '../models/pet_profile.dart';
import '../models/visit.dart';

/// CSV 한 칸을 안전하게 감싼다(쉼표·따옴표·줄바꿈 포함 시 큰따옴표로).
String csvCell(String v) {
  if (v.contains(',') ||
      v.contains('"') ||
      v.contains('\n') ||
      v.contains('\r')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

/// 방문·지출 표. 한글이 엑셀에서 깨지지 않도록 맨 앞에 BOM을 붙인다.
String visitsCsv(List<Visit> visits) {
  const header = [
    '날짜',
    '시간',
    '구분',
    '상태',
    '장소',
    '금액(원)',
    '내용',
    '처방·처치',
    '메모',
    '다음 예약일',
    '작성자',
    '사진 수',
  ];
  final rows = <String>[header.join(',')];
  for (final v in [...visits]..sort((a, b) => a.date.compareTo(b.date))) {
    rows.add(
      [
        v.date,
        v.time,
        v.type,
        v.status,
        v.placeName,
        v.amount.toString(),
        v.detail,
        v.prescription,
        v.memo,
        v.nextDate,
        v.author,
        v.photoCount.toString(),
      ].map(csvCell).join(','),
    );
  }
  return '﻿${rows.join('\r\n')}\r\n';
}

/// 전체 백업(JSON). 일기·방문의 사진과 댓글까지 포함한다.
Future<String> buildBackupJson({
  required PetProfile profile,
  required DiaryStore diaryStore,
  required VisitStore visitStore,
  RecordStore<WeightLog>? weightStore,
  RecordStore<HealthRecord>? healthStore,
  void Function(String step)? onProgress,
  DateTime? now,
}) async {
  onProgress?.call('일기를 모으는 중');
  final diary = <Map<String, dynamic>>[];
  for (final e in await diaryStore.load()) {
    final comments = await diaryStore.loadComments(e.id);
    final reactions = await diaryStore.loadReactions(e.id);
    diary.add({
      ...e.toMap(),
      'comments': [
        for (final c in comments) {'id': c.id, ...c.toMap()},
      ],
      'reactions': [
        for (final r in reactions)
          {'userId': r.userId, 'author': r.author, 'emoji': r.emoji},
      ],
    });
  }
  onProgress?.call('방문 기록을 모으는 중');
  final visits = <Map<String, dynamic>>[];
  for (final v in await visitStore.load()) {
    final photos = await visitStore.loadPhotos(v.id);
    visits.add(v.copyWith(photos: photos).toMap());
  }
  onProgress?.call('체중·접종 기록을 모으는 중');
  final weights = [
    for (final w in await weightStore?.load() ?? <WeightLog>[]) w.toMap(),
  ];
  final health = [
    for (final h in await healthStore?.load() ?? <HealthRecord>[]) h.toMap(),
  ];
  return const JsonEncoder.withIndent(' ').convert({
    'app': '치오 데일리',
    'version': 2,
    'exportedAt': (now ?? DateTime.now()).toIso8601String(),
    'profile': profile.toMap(),
    'diary': diary,
    'visits': visits,
    'weights': weights,
    'health': health,
  });
}

String backupFileName(String prefix, String ext, [DateTime? now]) {
  final n = now ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '$prefix-${n.year}-${two(n.month)}-${two(n.day)}.$ext';
}

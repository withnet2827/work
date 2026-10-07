import 'dart:convert';

import '../data/diary_store.dart';
import '../data/record_store.dart';
import '../data/visit_store.dart';
import '../models/diary_comment.dart';
import '../models/diary_entry.dart';
import '../models/health_record.dart';
import '../models/pet_profile.dart';
import '../models/visit.dart';
import '../models/weight_log.dart';

/// 백업 파일의 내용 요약(복원 전 확인용).
class BackupPreview {
  const BackupPreview({
    required this.data,
    required this.exportedAt,
    required this.hasProfile,
    required this.diary,
    required this.visits,
    required this.weights,
    required this.health,
  });
  final Map<String, dynamic> data;
  final String exportedAt;
  final bool hasProfile;
  final int diary;
  final int visits;
  final int weights;
  final int health;

  int get total => diary + visits + weights + health;
}

class RestoreResult {
  const RestoreResult({
    this.profile = false,
    this.diary = 0,
    this.comments = 0,
    this.visits = 0,
    this.weights = 0,
    this.health = 0,
    this.skipped = 0,
  });
  final bool profile;
  final int diary;
  final int comments;
  final int visits;
  final int weights;
  final int health;
  final int skipped; // 형식이 잘못되어 건너뛴 항목 수
}

List<Map<String, dynamic>> _list(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v is! List) return const [];
  return [
    for (final e in v)
      if (e is Map) Map<String, dynamic>.from(e),
  ];
}

/// 백업 파일 내용을 읽어 검증한다. 우리 앱 백업이 아니면 FormatException.
BackupPreview parseBackup(String json) {
  final dynamic decoded;
  try {
    decoded = jsonDecode(json);
  } catch (_) {
    throw const FormatException('올바른 백업 파일이 아닙니다. (JSON을 읽을 수 없어요)');
  }
  if (decoded is! Map || decoded['app'] != '치오 데일리') {
    throw const FormatException('치오 데일리에서 내려받은 백업 파일이 아닙니다.');
  }
  final data = Map<String, dynamic>.from(decoded);
  final version = (data['version'] as num?)?.toInt() ?? 1;
  if (version > 2) {
    throw const FormatException('더 새로운 버전의 백업 파일입니다. 앱을 최신으로 업데이트해 주세요.');
  }
  return BackupPreview(
    data: data,
    exportedAt: data['exportedAt'] as String? ?? '',
    hasProfile: data['profile'] is Map,
    diary: _list(data, 'diary').length,
    visits: _list(data, 'visits').length,
    weights: _list(data, 'weights').length,
    health: _list(data, 'health').length,
  );
}

/// 백업을 현재 저장소에 합친다. 같은 ID는 덮어쓰고, 없는 항목은 추가하며, 기존 기록은 지우지 않는다.
Future<RestoreResult> restoreBackup({
  required BackupPreview preview,
  required bool includeProfile,
  required Future<void> Function(PetProfile) saveProfile,
  required DiaryStore diaryStore,
  required VisitStore visitStore,
  required RecordStore<WeightLog> weightStore,
  required RecordStore<HealthRecord> healthStore,
  void Function(String step)? onProgress,
}) async {
  final d = preview.data;
  var skipped = 0;
  var profile = false;

  if (includeProfile && d['profile'] is Map) {
    onProgress?.call('프로필 복원 중');
    await saveProfile(
      PetProfile.fromMap(Map<String, dynamic>.from(d['profile'] as Map)),
    );
    profile = true;
  }

  var diaryCount = 0, commentCount = 0;
  final diary = _list(d, 'diary');
  for (var i = 0; i < diary.length; i++) {
    onProgress?.call('일기 복원 중 (${i + 1}/${diary.length})');
    try {
      final m = diary[i];
      final entry = DiaryEntry.fromMap(m);
      await diaryStore.save(entry);
      diaryCount++;
      // 댓글은 이미 있는 것은 건너뛰어 집계가 중복 증가하지 않게 한다.
      final existing = (await diaryStore.loadComments(entry.id))
          .map((c) => c.id)
          .toSet();
      for (final c in _list(m, 'comments')) {
        final id = c['id'] as String?;
        if (id == null || existing.contains(id)) continue;
        await diaryStore.addComment(entry.id, DiaryComment.fromMap(c, id: id));
        commentCount++;
      }
      for (final r in _list(m, 'reactions')) {
        final uid = r['userId'] as String?;
        final emoji = r['emoji'] as String?;
        if (uid == null || emoji == null) continue;
        await diaryStore.setReaction(
          entry.id,
          uid,
          r['author'] as String? ?? '',
          emoji,
        );
      }
    } catch (_) {
      skipped++;
    }
  }

  var visitCount = 0;
  final visits = _list(d, 'visits');
  for (var i = 0; i < visits.length; i++) {
    onProgress?.call('방문 기록 복원 중 (${i + 1}/${visits.length})');
    try {
      await visitStore.save(Visit.fromMap(visits[i]));
      visitCount++;
    } catch (_) {
      skipped++;
    }
  }

  var weightCount = 0;
  onProgress?.call('체중 복원 중');
  for (final m in _list(d, 'weights')) {
    try {
      await weightStore.save(WeightLog.fromMap(m));
      weightCount++;
    } catch (_) {
      skipped++;
    }
  }

  var healthCount = 0;
  onProgress?.call('접종·예방약 복원 중');
  for (final m in _list(d, 'health')) {
    try {
      await healthStore.save(HealthRecord.fromMap(m));
      healthCount++;
    } catch (_) {
      skipped++;
    }
  }

  return RestoreResult(
    profile: profile,
    diary: diaryCount,
    comments: commentCount,
    visits: visitCount,
    weights: weightCount,
    health: healthCount,
    skipped: skipped,
  );
}

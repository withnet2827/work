import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/diary_comment.dart';
import '../models/diary_entry.dart';
import 'diary_store.dart';

/// 가족 공유 일기 저장소.
///  - families/{id}/diary/{entryId}        : 본문·날짜·기분·작성자(사진 제외)
///  - families/{id}/diaryPhotos/{entryId}_{n} : 사진 1장 = 문서 1개 {entryId, idx, b64}
/// 일기 1편이 문서 1개라서 가족이 동시에 서로 다른 일기를 써도 덮어쓰지 않는다.
class FirestoreDiaryStore implements DiaryStore {
  FirestoreDiaryStore(this.familyId, [FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;
  final String familyId;
  final FirebaseFirestore _db;

  static const _limit = 60; // 최근 일기만 불러온다
  static const _maxPhotoChars = 900000;

  CollectionReference<Map<String, dynamic>> get _entries =>
      _db.collection('families').doc(familyId).collection('diary');
  CollectionReference<Map<String, dynamic>> get _photos =>
      _db.collection('families').doc(familyId).collection('diaryPhotos');

  @override
  Future<List<DiaryEntry>> load() async {
    final snap = await _entries
        .orderBy('date', descending: true)
        .limit(_limit)
        .get();
    final ids = snap.docs.map((d) => d.id).toList();
    final photosById = <String, List<MapEntry<int, String>>>{};
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final ps = await _photos.where('entryId', whereIn: chunk).get();
      for (final d in ps.docs) {
        final m = d.data();
        photosById
            .putIfAbsent(m['entryId'] as String, () => [])
            .add(
              MapEntry(
                (m['idx'] as num?)?.toInt() ?? 0,
                m['b64'] as String? ?? '',
              ),
            );
      }
    }
    final list = [
      for (final d in snap.docs)
        DiaryEntry.fromMap(
          d.data(),
          id: d.id,
          photos:
              ((photosById[d.id] ?? []).toList()
                    ..sort((a, b) => a.key.compareTo(b.key)))
                  .map((e) => e.value)
                  .toList(),
        ),
    ];
    return list..sort(compareEntries);
  }

  @override
  Future<void> save(DiaryEntry entry) async {
    for (final p in entry.photos) {
      if (p.length > _maxPhotoChars) {
        throw StateError('사진 용량이 너무 큽니다. 더 작은 사진을 사용해 주세요.');
      }
    }
    final keep = <String>{};
    for (var i = 0; i < entry.photos.length; i++) {
      final id = '${entry.id}_$i';
      keep.add(id);
      await _photos.doc(id).set({
        'entryId': entry.id,
        'idx': i,
        'b64': entry.photos[i],
      });
    }
    // 줄어든 사진 정리
    final old = await _photos.where('entryId', isEqualTo: entry.id).get();
    for (final d in old.docs) {
      if (!keep.contains(d.id)) await d.reference.delete();
    }
    // merge: 서버가 관리하는 commentCount·reactionCount를 덮어쓰지 않는다.
    await _entries.doc(entry.id).set(entry.toMeta(), SetOptions(merge: true));
  }

  @override
  Future<void> delete(String id) async {
    final old = await _photos.where('entryId', isEqualTo: id).get();
    for (final d in old.docs) {
      await d.reference.delete();
    }
    for (final sub in ['comments', 'reactions']) {
      final docs = await _entries.doc(id).collection(sub).get();
      for (final d in docs.docs) {
        await d.reference.delete();
      }
    }
    await _entries.doc(id).delete();
  }

  // ---- 댓글·공감: diary/{id}/comments/{cid}, diary/{id}/reactions/{uid} ----
  @override
  Future<List<DiaryComment>> loadComments(String entryId) async {
    final snap = await _entries
        .doc(entryId)
        .collection('comments')
        .orderBy('createdAt')
        .get();
    return [
      for (final d in snap.docs) DiaryComment.fromMap(d.data(), id: d.id),
    ];
  }

  @override
  Future<void> addComment(String entryId, DiaryComment c) async {
    final ref = _entries.doc(entryId);
    await ref.collection('comments').doc(c.id).set(c.toMap());
    await ref.update({'commentCount': FieldValue.increment(1)});
  }

  @override
  Future<void> deleteComment(String entryId, String commentId) async {
    final ref = _entries.doc(entryId);
    await ref.collection('comments').doc(commentId).delete();
    await ref.update({'commentCount': FieldValue.increment(-1)});
  }

  @override
  Future<List<DiaryReaction>> loadReactions(String entryId) async {
    final snap = await _entries.doc(entryId).collection('reactions').get();
    return [
      for (final d in snap.docs)
        DiaryReaction(
          userId: d.id,
          author: d.data()['author'] as String? ?? '',
          emoji: d.data()['emoji'] as String? ?? '',
        ),
    ];
  }

  @override
  Future<void> setReaction(
    String entryId,
    String userId,
    String author,
    String? emoji,
  ) async {
    final ref = _entries.doc(entryId);
    final mine = ref.collection('reactions').doc(userId);
    final had = (await mine.get()).exists;
    if (emoji == null) {
      if (had) {
        await mine.delete();
        await ref.update({'reactionCount': FieldValue.increment(-1)});
      }
    } else {
      await mine.set({'author': author, 'emoji': emoji});
      if (!had) await ref.update({'reactionCount': FieldValue.increment(1)});
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attachment.dart';
import '../models/visit.dart';
import 'visit_store.dart';

/// 가족 공유 방문 기록.
///  - families/{id}/visits/{visitId}            : 방문 정보(사진 제외)
///  - families/{id}/visitPhotos/{visitId}_{n}   : 사진 1장 = 문서 1개 {visitId, idx, label, date, b64}
class FirestoreVisitStore implements VisitStore {
  FirestoreVisitStore(this.familyId, [FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;
  final String familyId;
  final FirebaseFirestore _db;

  static const _limit = 200;
  static const _maxPhotoChars = 900000;

  CollectionReference<Map<String, dynamic>> get _visits =>
      _db.collection('families').doc(familyId).collection('visits');
  CollectionReference<Map<String, dynamic>> get _photos =>
      _db.collection('families').doc(familyId).collection('visitPhotos');

  @override
  Future<List<Visit>> load() async {
    final snap = await _visits
        .orderBy('date', descending: true)
        .limit(_limit)
        .get();
    return [
      for (final d in snap.docs)
        Visit.fromMap(d.data(), id: d.id, photos: const []),
    ]..sort(compareVisits);
  }

  @override
  Future<List<Attachment>> loadPhotos(String visitId) async {
    final ps = await _photos.where('visitId', isEqualTo: visitId).get();
    final list = ps.docs.map((d) => d.data()).toList()
      ..sort(
        (a, b) => ((a['idx'] as num?) ?? 0).compareTo((b['idx'] as num?) ?? 0),
      );
    return [
      for (var i = 0; i < list.length; i++)
        Attachment(
          id: '${visitId}_$i',
          photoBase64: list[i]['b64'] as String? ?? '',
          label: list[i]['label'] as String? ?? '기타',
          date: list[i]['date'] as String? ?? '',
        ),
    ];
  }

  @override
  Future<void> save(Visit visit) async {
    for (final p in visit.photos) {
      if (p.photoBase64.length > _maxPhotoChars) {
        throw StateError('사진 용량이 너무 큽니다. 더 작은 사진을 사용해 주세요.');
      }
    }
    final keep = <String>{};
    for (var i = 0; i < visit.photos.length; i++) {
      final p = visit.photos[i];
      final id = '${visit.id}_$i';
      keep.add(id);
      await _photos.doc(id).set({
        'visitId': visit.id,
        'idx': i,
        'label': p.label,
        'date': p.date,
        'b64': p.photoBase64,
      });
    }
    final old = await _photos.where('visitId', isEqualTo: visit.id).get();
    for (final d in old.docs) {
      if (!keep.contains(d.id)) {
        await d.reference.delete();
      }
    }
    await _visits.doc(visit.id).set(visit.toMeta());
  }

  @override
  Future<void> delete(String id) async {
    final old = await _photos.where('visitId', isEqualTo: id).get();
    for (final d in old.docs) {
      await d.reference.delete();
    }
    await _visits.doc(id).delete();
  }
}

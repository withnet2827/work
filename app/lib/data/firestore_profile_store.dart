import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pet_profile.dart';
import 'change_source.dart';
import 'profile_store.dart';

/// 가족 공유 저장소(Firestore).
///  - families/{id}/data/profile : 프로필 텍스트 정보(사진 제외)
///  - families/{id}/photos/{photoId} : 압축된 사진 1장 = 문서 1개(Firestore 문서 1MB 제한 때문에 분리)
/// 사진 id: 'profile'(대표 사진), 'att_<첨부id>'
class FirestoreProfileStore implements ProfileStore, ChangeSource {
  FirestoreProfileStore(this.familyId, [FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;
  final String familyId;
  final FirebaseFirestore _db;

  /// 마지막으로 서버와 맞춘 사진 id → 내용 해시. 바뀐 사진만 올리기 위함.
  final Map<String, int> _known = {};

  static const _maxPhotoChars = 900000; // base64 문자 수. 문서 1MB 제한 여유

  DocumentReference<Map<String, dynamic>> get _profileDoc => _db
      .collection('families')
      .doc(familyId)
      .collection('data')
      .doc('profile');
  CollectionReference<Map<String, dynamic>> get _photos =>
      _db.collection('families').doc(familyId).collection('photos');

  @override
  Stream<void> get changes => _profileDoc.snapshots().skip(1).map((_) {});

  @override
  Future<PetProfile> load() async {
    final snap = await _profileDoc.get();
    if (!snap.exists) return const PetProfile();
    final photoSnap = await _photos.get();
    final photos = {
      for (final d in photoSnap.docs) d.id: d.data()['b64'] as String? ?? '',
    };
    _known
      ..clear()
      ..addEntries(
        photos.entries.map((e) => MapEntry(e.key, e.value.hashCode)),
      );

    final m = Map<String, dynamic>.from(snap.data()!);
    m['photoBase64'] = photos['profile'] ?? '';
    final places = <Map<String, dynamic>>[];
    for (final p in (m['places'] as List? ?? const [])) {
      final pm = Map<String, dynamic>.from(p as Map);
      pm['attachments'] = [
        for (final a in (pm['attachments'] as List? ?? const []))
          {
            ...Map<String, dynamic>.from(a as Map),
            'photoBase64': photos['att_${a['id']}'] ?? '',
          },
      ];
      places.add(pm);
    }
    m['places'] = places;
    return PetProfile.fromMap(m);
  }

  @override
  Future<void> save(PetProfile profile) async {
    final photos = <String, String>{};
    if (profile.photoBase64.isNotEmpty) photos['profile'] = profile.photoBase64;

    final m = profile.toMap();
    m['photoBase64'] = '';
    m['places'] = [
      for (final place in profile.places)
        {
          ...place.toMap(),
          'attachments': [
            for (final a in place.attachments)
              () {
                photos['att_${a.id}'] = a.photoBase64;
                return {'id': a.id, 'label': a.label, 'date': a.date};
              }(),
          ],
        },
    ];

    for (final e in photos.entries) {
      if (e.value.length > _maxPhotoChars) {
        throw StateError('사진 용량이 너무 큽니다. 더 작은 사진을 사용해 주세요.');
      }
    }
    // 바뀐 사진만 업로드
    for (final e in photos.entries) {
      if (_known[e.key] == e.value.hashCode) continue;
      await _photos.doc(e.key).set({'b64': e.value});
      _known[e.key] = e.value.hashCode;
    }
    await _profileDoc.set(m);
    // 더 이상 쓰지 않는 사진 삭제
    for (final id
        in _known.keys.where((k) => !photos.containsKey(k)).toList()) {
      await _photos.doc(id).delete();
      _known.remove(id);
    }
  }
}

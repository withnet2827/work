import 'package:cloud_firestore/cloud_firestore.dart';

import 'record_store.dart';

/// 가족 공유 저장소: families/{familyId}/{collection}/{id} 문서 1개 = 기록 1건.
class FirestoreRecordStore<T> implements RecordStore<T> {
  FirestoreRecordStore({
    required this.familyId,
    required this.collection,
    required this.toMap,
    required this.fromMap,
    required this.idOf,
    this.limit = 1000,
    FirebaseFirestore? db,
  }) : _db = db ?? FirebaseFirestore.instance;
  final String familyId;
  final String collection;
  final Map<String, dynamic> Function(T) toMap;
  final T Function(Map<String, dynamic>) fromMap;
  final String Function(T) idOf;
  final int limit;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('families').doc(familyId).collection(collection);

  @override
  Future<List<T>> load() async {
    final snap = await _col.limit(limit).get();
    return [
      for (final d in snap.docs) fromMap({...d.data(), 'id': d.id}),
    ];
  }

  @override
  Future<void> save(T item) => _col.doc(idOf(item)).set(toMap(item));

  @override
  Future<void> delete(String id) => _col.doc(id).delete();
}

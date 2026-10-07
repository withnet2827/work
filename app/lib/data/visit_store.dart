import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/attachment.dart';
import '../models/visit.dart';

/// 방문 기록 저장소. 목록(load)은 사진 없이, 사진은 상세에서 loadPhotos로 따로 읽는다.
abstract class VisitStore {
  Future<List<Visit>> load();
  Future<List<Attachment>> loadPhotos(String visitId);
  Future<void> save(Visit visit);
  Future<void> delete(String id);
}

int compareVisits(Visit a, Visit b) {
  final c = ('${b.date} ${b.time}').compareTo('${a.date} ${a.time}');
  return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
}

class LocalVisitStore implements VisitStore {
  static const _key = 'visits_v1';

  Future<List<Visit>> _read() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_key);
    if (s == null) return [];
    return [
      for (final e in jsonDecode(s) as List)
        Visit.fromMap(Map<String, dynamic>.from(e as Map)),
    ];
  }

  Future<void> _write(List<Visit> list) async {
    final p = await SharedPreferences.getInstance();
    final ok = await p.setString(
      _key,
      jsonEncode(list.map((e) => e.toMap()).toList()),
    );
    if (!ok) throw StateError('저장 공간이 부족합니다.');
  }

  @override
  Future<List<Visit>> load() async => (await _read())..sort(compareVisits);

  @override
  Future<List<Attachment>> loadPhotos(String visitId) async {
    final v = (await _read()).where((e) => e.id == visitId);
    return v.isEmpty ? [] : v.first.photos;
  }

  @override
  Future<void> save(Visit visit) async {
    final list = await _read();
    final i = list.indexWhere((e) => e.id == visit.id);
    if (i >= 0) {
      list[i] = visit;
    } else {
      list.add(visit);
    }
    await _write(list);
  }

  @override
  Future<void> delete(String id) async {
    final list = await _read()
      ..removeWhere((e) => e.id == id);
    await _write(list);
  }
}

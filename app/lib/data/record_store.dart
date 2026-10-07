import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 단순 기록(체중·접종 등) 저장소 공통 인터페이스.
abstract class RecordStore<T> {
  Future<List<T>> load();
  Future<void> save(T item);
  Future<void> delete(String id);
}

/// 이 기기에만 저장하는 구현(로컬 모드).
class LocalRecordStore<T> implements RecordStore<T> {
  LocalRecordStore({
    required this.key,
    required this.toMap,
    required this.fromMap,
    required this.idOf,
  });
  final String key;
  final Map<String, dynamic> Function(T) toMap;
  final T Function(Map<String, dynamic>) fromMap;
  final String Function(T) idOf;

  Future<List<T>> _read() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(key);
    if (s == null) return [];
    return [
      for (final e in jsonDecode(s) as List)
        fromMap(Map<String, dynamic>.from(e as Map)),
    ];
  }

  Future<void> _write(List<T> list) async {
    final p = await SharedPreferences.getInstance();
    final ok = await p.setString(key, jsonEncode(list.map(toMap).toList()));
    if (!ok) throw StateError('저장 공간이 부족합니다.');
  }

  @override
  Future<List<T>> load() => _read();

  @override
  Future<void> save(T item) async {
    final list = await _read();
    final i = list.indexWhere((e) => idOf(e) == idOf(item));
    if (i >= 0) {
      list[i] = item;
    } else {
      list.add(item);
    }
    await _write(list);
  }

  @override
  Future<void> delete(String id) async {
    final list = await _read()
      ..removeWhere((e) => idOf(e) == id);
    await _write(list);
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/diary_entry.dart';

/// 일기 저장소 인터페이스. 목록은 최신 날짜순으로 돌려준다.
abstract class DiaryStore {
  Future<List<DiaryEntry>> load();
  Future<void> save(DiaryEntry entry);
  Future<void> delete(String id);
}

int compareEntries(DiaryEntry a, DiaryEntry b) {
  final c = b.date.compareTo(a.date);
  return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
}

class LocalDiaryStore implements DiaryStore {
  static const _key = 'diary_v1';

  Future<List<DiaryEntry>> _read() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_key);
    if (s == null) return [];
    return [
      for (final e in jsonDecode(s) as List)
        DiaryEntry.fromMap(Map<String, dynamic>.from(e as Map)),
    ];
  }

  Future<void> _write(List<DiaryEntry> list) async {
    final p = await SharedPreferences.getInstance();
    final ok = await p.setString(
      _key,
      jsonEncode(list.map((e) => e.toMap()).toList()),
    );
    if (!ok) throw StateError('저장 공간이 부족합니다.');
  }

  @override
  Future<List<DiaryEntry>> load() async =>
      (await _read())..sort(compareEntries);

  @override
  Future<void> save(DiaryEntry entry) async {
    final list = await _read();
    final i = list.indexWhere((e) => e.id == entry.id);
    if (i >= 0) {
      list[i] = entry;
    } else {
      list.add(entry);
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

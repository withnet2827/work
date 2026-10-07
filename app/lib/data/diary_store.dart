import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/diary_comment.dart';
import '../models/diary_entry.dart';

/// 일기 저장소 인터페이스. 목록은 최신 날짜순으로 돌려준다.
abstract class DiaryStore {
  Future<List<DiaryEntry>> load();
  Future<void> save(DiaryEntry entry);
  Future<void> delete(String id);

  Future<List<DiaryComment>> loadComments(String entryId);
  Future<void> addComment(String entryId, DiaryComment comment);
  Future<void> deleteComment(String entryId, String commentId);

  Future<List<DiaryReaction>> loadReactions(String entryId);

  /// 내 공감을 바꾼다. emoji가 null이면 공감을 취소한다.
  Future<void> setReaction(
    String entryId,
    String userId,
    String author,
    String? emoji,
  );
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
  Future<List<DiaryEntry>> load() async {
    final comments = await _readMap(_commentsKey);
    final reactions = await _readMap(_reactionsKey);
    final list = [
      for (final e in await _read())
        e.withCounts(
          comments: (comments[e.id] as List? ?? const []).length,
          reactions: (reactions[e.id] as Map? ?? const {}).length,
        ),
    ];
    return list..sort(compareEntries);
  }

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

  // ---- 댓글·공감 (이 기기에만 저장) ----
  static const _commentsKey = 'diary_comments_v1';
  static const _reactionsKey = 'diary_reactions_v1';

  Future<Map<String, dynamic>> _readMap(String key) async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(key);
    return s == null ? {} : Map<String, dynamic>.from(jsonDecode(s) as Map);
  }

  Future<void> _writeMap(String key, Map<String, dynamic> m) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode(m));
  }

  @override
  Future<List<DiaryComment>> loadComments(String entryId) async {
    final m = await _readMap(_commentsKey);
    final list = [
      for (final e in (m[entryId] as List? ?? const []))
        DiaryComment.fromMap(Map<String, dynamic>.from(e as Map)),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<void> addComment(String entryId, DiaryComment c) async {
    final m = await _readMap(_commentsKey);
    final list = List<dynamic>.from(m[entryId] as List? ?? const []);
    list.add({'id': c.id, ...c.toMap()});
    m[entryId] = list;
    await _writeMap(_commentsKey, m);
  }

  @override
  Future<void> deleteComment(String entryId, String commentId) async {
    final m = await _readMap(_commentsKey);
    final list = List<dynamic>.from(m[entryId] as List? ?? const [])
      ..removeWhere((e) => (e as Map)['id'] == commentId);
    m[entryId] = list;
    await _writeMap(_commentsKey, m);
  }

  @override
  Future<List<DiaryReaction>> loadReactions(String entryId) async {
    final m = await _readMap(_reactionsKey);
    final byUser = Map<String, dynamic>.from(m[entryId] as Map? ?? const {});
    return [
      for (final e in byUser.entries)
        DiaryReaction(
          userId: e.key,
          author: (e.value as Map)['author'] as String? ?? '',
          emoji: (e.value as Map)['emoji'] as String? ?? '',
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
    final m = await _readMap(_reactionsKey);
    final byUser = Map<String, dynamic>.from(m[entryId] as Map? ?? const {});
    if (emoji == null) {
      byUser.remove(userId);
    } else {
      byUser[userId] = {'author': author, 'emoji': emoji};
    }
    m[entryId] = byUser;
    await _writeMap(_reactionsKey, m);
  }
}

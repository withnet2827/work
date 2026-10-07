import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/diary_store.dart';
import '../models/attachment.dart';
import '../models/diary_entry.dart';
import 'attachment_viewer_screen.dart';
import 'diary_detail_screen.dart';
import 'diary_edit_screen.dart';

/// 일기 탭: 월별로 묶은 타임라인.
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({
    super.key,
    required this.store,
    required this.authorName,
    this.userId = 'local',
  });
  final DiaryStore store;
  final String authorName;
  final String userId;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  List<DiaryEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final list = await widget.store.load();
      if (mounted) {
        setState(() {
          _entries = list;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _open(DiaryEntry entry, {required bool isNew}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiaryEditScreen(
          entry: entry,
          isNew: isNew,
          onSave: (e) async {
            await widget.store.save(e);
            await _reload();
          },
          onDelete: isNew
              ? null
              : () async {
                  await widget.store.delete(entry.id);
                  await _reload();
                },
        ),
      ),
    );
  }

  /// 확인 후 일기 삭제(사진·댓글·공감 포함). 삭제했으면 true.
  Future<bool> _confirmDelete(DiaryEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('일기 삭제'),
        content: Text('${e.date} 일기를 삭제할까요?\n사진과 댓글도 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    try {
      await widget.store.delete(e.id);
      await _reload();
      return true;
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('삭제하지 못했습니다. $err')));
      }
      return false;
    }
  }

  void _openDetail(DiaryEntry e) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiaryDetailScreen(
          entry: e,
          store: widget.store,
          userId: widget.userId,
          userName: widget.authorName,
          onEdit: () => _open(e, isNew: false),
          onDelete: () => _confirmDelete(e),
          onChanged: _reload,
        ),
      ),
    );
  }

  void _write() {
    final now = DateTime.now();
    _open(
      DiaryEntry(
        id: now.microsecondsSinceEpoch.toString(),
        date: todayString(now),
        author: widget.authorName,
        createdAt: now.millisecondsSinceEpoch,
      ),
      isNew: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('일기를 불러오지 못했습니다.\n$_error'),
        ),
      );
    } else if (_entries.isEmpty) {
      body = const Center(
        child: Text(
          '아직 일기가 없어요.\n아래 버튼으로 첫 일기를 써 보세요.',
          textAlign: TextAlign.center,
        ),
      );
    } else {
      final children = <Widget>[];
      String month = '';
      for (final e in _entries) {
        final m = e.date.length >= 7 ? e.date.substring(0, 7) : e.date;
        if (m != month) {
          month = m;
          children.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
              child: Text(m, style: text.titleSmall),
            ),
          );
        }
        children.add(
          _EntryCard(
            entry: e,
            onTap: () => _openDetail(e),
            onEdit: () => _open(e, isNew: false),
            onDelete: () => _confirmDelete(e),
          ),
        );
      }
      body = RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: children,
        ),
      );
    }
    return Scaffold(
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _write,
        icon: const Icon(Icons.edit),
        label: const Text('일기 쓰기'),
      ),
    );
  }
}

int _walkMinutes(DiaryEntry e) => e.walks.fold(0, (a, w) => a + w.minutes);

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });
  final DiaryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (entry.mood.isNotEmpty)
                    Text(
                      '${entry.mood}  ',
                      style: const TextStyle(fontSize: 20),
                    ),
                  Text(entry.date, style: text.titleSmall),
                  const Spacer(),
                  if (entry.author.isNotEmpty)
                    Text(entry.author, style: text.bodySmall),
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: '수정',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: '삭제',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (entry.walks.isNotEmpty || entry.feeds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    [
                      if (entry.walks.isNotEmpty)
                        '🚶 산책 ${entry.walks.length}회${_walkMinutes(entry) > 0 ? ' (${_walkMinutes(entry)}분)' : ''}',
                      if (entry.feeds.isNotEmpty)
                        '🍖 추가 급여 ${entry.feeds.length}건',
                    ].join('   '),
                    style: text.bodySmall,
                  ),
                ),
              if (entry.commentCount > 0 || entry.reactionCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    [
                      if (entry.reactionCount > 0) '❤️ ${entry.reactionCount}',
                      if (entry.commentCount > 0) '💬 ${entry.commentCount}',
                    ].join('  '),
                    style: text.bodySmall,
                  ),
                ),
              if (entry.body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(entry.body, maxLines: 5, overflow: TextOverflow.ellipsis),
              ],
              if (entry.photos.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: entry.photos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (c, i) => GestureDetector(
                      onTap: () => Navigator.of(c).push(
                        MaterialPageRoute(
                          builder: (_) => AttachmentViewerScreen(
                            attachments: [
                              for (var k = 0; k < entry.photos.length; k++)
                                Attachment(
                                  id: '$k',
                                  photoBase64: entry.photos[k],
                                  label: '일기',
                                  date: entry.date,
                                ),
                            ],
                            initialIndex: i,
                            canDelete: false,
                            onDelete: (_) {},
                          ),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(entry.photos[i]),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

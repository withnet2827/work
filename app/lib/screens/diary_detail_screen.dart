import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/diary_store.dart';
import '../models/attachment.dart';
import '../models/diary_comment.dart';
import '../models/diary_entry.dart';
import 'attachment_viewer_screen.dart';

/// 일기 상세: 본문·사진, 공감, 댓글. 수정은 앱바 연필 아이콘.
class DiaryDetailScreen extends StatefulWidget {
  const DiaryDetailScreen({
    super.key,
    required this.entry,
    required this.store,
    required this.userId,
    required this.userName,
    required this.onEdit,
    required this.onChanged,
  });
  final DiaryEntry entry;
  final DiaryStore store;
  final String userId;
  final String userName;
  final VoidCallback onEdit; // 수정 화면 열기(상세는 닫힌다)
  final Future<void> Function() onChanged; // 댓글·공감 변경 후 목록 집계 새로고침

  @override
  State<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends State<DiaryDetailScreen> {
  List<DiaryComment> _comments = [];
  List<DiaryReaction> _reactions = [];
  final _input = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _load() async {
    try {
      final c = await widget.store.loadComments(widget.entry.id);
      final r = await widget.store.loadReactions(widget.entry.id);
      if (mounted) {
        setState(() {
          _comments = c;
          _reactions = r;
        });
      }
    } catch (e) {
      _toast('댓글을 불러오지 못했습니다. $e');
    }
  }

  String? get _myEmoji {
    for (final r in _reactions) {
      if (r.userId == widget.userId) return r.emoji;
    }
    return null;
  }

  Future<void> _react(String emoji) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.store.setReaction(
        widget.entry.id,
        widget.userId,
        widget.userName,
        _myEmoji == emoji ? null : emoji,
      );
      await _load();
      await widget.onChanged();
    } catch (e) {
      _toast('공감을 저장하지 못했습니다. $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      await widget.store.addComment(
        widget.entry.id,
        DiaryComment(
          id: now.microsecondsSinceEpoch.toString(),
          author: widget.userName,
          authorId: widget.userId,
          text: text,
          createdAt: now.millisecondsSinceEpoch,
        ),
      );
      _input.clear();
      await _load();
      await widget.onChanged();
    } catch (e) {
      _toast('댓글을 저장하지 못했습니다. $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _deleteComment(DiaryComment c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('이 댓글을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.store.deleteComment(widget.entry.id, c.id);
      await _load();
      await widget.onChanged();
    } catch (e) {
      _toast('삭제하지 못했습니다. $e');
    }
  }

  void _openPhoto(int i) {
    final e = widget.entry;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttachmentViewerScreen(
          attachments: [
            for (var k = 0; k < e.photos.length; k++)
              Attachment(
                id: '$k',
                photoBase64: e.photos[k],
                label: '일기',
                date: e.date,
              ),
          ],
          initialIndex: i,
          canDelete: false,
          onDelete: (_) {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final text = Theme.of(context).textTheme;
    final mine = _myEmoji;
    return Scaffold(
      appBar: AppBar(
        title: Text(e.date),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onEdit();
            },
            icon: const Icon(Icons.edit_outlined),
            tooltip: '수정',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    if (e.mood.isNotEmpty)
                      Text('${e.mood}  ', style: const TextStyle(fontSize: 24)),
                    if (e.author.isNotEmpty)
                      Text(e.author, style: text.titleSmall),
                  ],
                ),
                if (e.walks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('🚶 산책 ${e.walks.length}회', style: text.titleSmall),
                  for (var i = 0; i < e.walks.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${i + 1}회  ${e.walks[i].summary}${e.walks[i].memo.isEmpty ? '' : '\n      ${e.walks[i].memo}'}',
                      ),
                    ),
                ],
                if (e.feeds.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('🍖 추가 급여 ${e.feeds.length}건', style: text.titleSmall),
                  for (final f in e.feeds)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${f.summary}${f.memo.isEmpty ? '' : '\n  ${f.memo}'}',
                      ),
                    ),
                ],
                if (e.body.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SelectableText(e.body, style: text.bodyLarge),
                ],
                if (e.photos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (var i = 0; i < e.photos.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => _openPhoto(i),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            base64Decode(e.photos[i]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                ],
                const Divider(height: 32),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final emoji in DiaryReaction.emojis)
                      ChoiceChip(
                        label: Text(
                          '$emoji ${_reactions.where((r) => r.emoji == emoji).length}',
                        ),
                        selected: mine == emoji,
                        onSelected: (_) => _react(emoji),
                      ),
                  ],
                ),
                if (_reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _reactions
                          .map((r) => r.author)
                          .where((a) => a.isNotEmpty)
                          .join(', '),
                      style: text.bodySmall,
                    ),
                  ),
                const SizedBox(height: 16),
                Text('댓글 ${_comments.length}', style: text.titleSmall),
                if (_comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('첫 댓글을 남겨 보세요.'),
                  ),
                for (final c in _comments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.text),
                    subtitle: Text('${c.author}  ${_when(c.createdAt)}'),
                    trailing: c.authorId == widget.userId
                        ? IconButton(
                            onPressed: () => _deleteComment(c),
                            icon: const Icon(Icons.delete_outline, size: 20),
                            tooltip: '삭제',
                          )
                        : null,
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: const InputDecoration(
                        hintText: '댓글 달기',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : _send,
                    icon: const Icon(Icons.send),
                    tooltip: '보내기',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _when(int ms) {
    if (ms == 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}

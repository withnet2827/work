import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/change_source.dart';
import '../data/record_store.dart';
import '../models/stool_log.dart';
import '../util/photo_compress.dart';
import 'diary_edit_screen.dart' show todayString;

/// 배변 기록: 굳기 점수·색·특이사항·사진. 참고용이며 진단이 아니다.
class StoolSection extends StatefulWidget {
  const StoolSection({
    super.key,
    required this.store,
    required this.authorName,
    this.onChanged,
  });
  final RecordStore<StoolLog> store;
  final String authorName;
  final VoidCallback? onChanged; // 홈의 주의 알림 갱신용

  @override
  State<StoolSection> createState() => _StoolSectionState();
}

class _StoolSectionState extends State<StoolSection> {
  List<StoolLog> _all = [];
  bool _loading = true;
  String? _error;
  ChangeWatcher? _watcher;

  @override
  void initState() {
    super.initState();
    _reload();
    _watcher = ChangeWatcher(widget.store, () async {
      await _reload();
      widget.onChanged?.call();
    });
  }

  @override
  void dispose() {
    _watcher?.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final list = await widget.store.load()
        ..sort((a, b) {
          final c = b.date.compareTo(a.date);
          return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
        });
      if (mounted) {
        setState(() {
          _all = list;
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

  void _toast(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _edit([StoolLog? s]) async {
    final now = DateTime.now();
    final result = await showModalBottomSheet<StoolLog>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StoolForm(
        initial:
            s ??
            StoolLog(
              id: now.microsecondsSinceEpoch.toString(),
              date: todayString(now),
              author: widget.authorName,
              createdAt: now.millisecondsSinceEpoch,
            ),
        isNew: s == null,
      ),
    );
    if (result == null) return;
    try {
      await widget.store.save(result);
      await _reload();
      widget.onChanged?.call();
    } catch (e) {
      _toast('저장하지 못했습니다. $e');
    }
  }

  Future<void> _delete(StoolLog s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('배변 기록 삭제'),
        content: Text('${s.date} 기록을 삭제할까요?'),
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
    if (ok != true) return;
    try {
      await widget.store.delete(s.id);
      await _reload();
      widget.onChanged?.call();
    } catch (e) {
      _toast('삭제하지 못했습니다. $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('기록을 불러오지 못했습니다.\n$_error'));
    final today = todayString();
    final alerts = StoolLog.recentAttention(_all, today);
    final urgent = alerts.any((s) => s.urgent);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (alerts.isNotEmpty)
              Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    urgent
                        ? '최근 3일 안에 붉은 피나 검은 변이 있었어요. 가능하면 오늘 병원에 상담해 보세요.'
                        : '최근 3일 안에 주의가 필요한 기록이 ${alerts.length}건 있어요. 이어지면 병원에 상담해 보세요.',
                    style: text.bodyMedium,
                  ),
                ),
              ),
            if (_all.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(
                    '아직 배변 기록이 없어요.\n아래 버튼으로 오늘 상태를 기록해 보세요.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            for (final s in _all)
              Card(
                color: s.needsAttention ? scheme.errorContainer : null,
                child: ListTile(
                  onTap: () => _edit(s),
                  leading: s.photo.isEmpty
                      ? CircleAvatar(child: Text('${s.score}'))
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(s.photo),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => CircleAvatar(
                              child: Text('${s.score}'),
                            ),
                          ),
                        ),
                  title: Text('${s.date}  ·  점수 ${s.score}  ·  ${s.color}'),
                  subtitle: Text(
                    [
                      StoolLog.scoreLabels[s.score] ?? '',
                      if (s.flags.isNotEmpty) s.flags.join(', '),
                      if (s.memo.isNotEmpty) s.memo,
                    ].where((e) => e.isNotEmpty).join(' · '),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '삭제',
                    onPressed: () => _delete(s),
                  ),
                ),
              ),
            if (_all.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '참고용 기록이에요. 진단이 아니며, 걱정되면 동물병원에 상담하세요.',
                  style: text.bodySmall,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'stool-fab',
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('배변 기록'),
      ),
    );
  }
}

class _StoolForm extends StatefulWidget {
  const _StoolForm({required this.initial, required this.isNew});
  final StoolLog initial;
  final bool isNew;

  @override
  State<_StoolForm> createState() => _StoolFormState();
}

class _StoolFormState extends State<_StoolForm> {
  late String _date = widget.initial.date;
  late int _score = widget.initial.score;
  late String _color = widget.initial.color;
  late final Set<String> _flags = {...widget.initial.flags};
  late String _photo = widget.initial.photo;
  late final _memo = TextEditingController(text: widget.initial.memo);

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('앨범에서 선택'),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final x = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 70,
    );
    if (x == null) return;
    // 기록이 많아져도 가볍도록 작게 줄인다(약 100KB).
    final b64 = compressPhoto(await x.readAsBytes(), targetChars: 140000);
    if (mounted) setState(() => _photo = b64);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.isNew ? '배변 기록' : '기록 수정', style: text.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(_date),
              onPressed: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.tryParse(_date) ?? now,
                  firstDate: DateTime(2000),
                  lastDate: now,
                );
                if (d != null) setState(() => _date = todayString(d));
              },
            ),
            const SizedBox(height: 12),
            Text('굳기 점수', style: text.titleSmall),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 1; i <= 7; i++)
                  ChoiceChip(
                    label: Text('$i'),
                    selected: _score == i,
                    onSelected: (_) => setState(() => _score = i),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                StoolLog.scoreLabels[_score] ?? '',
                style: text.bodySmall,
              ),
            ),
            const SizedBox(height: 12),
            Text('색', style: text.titleSmall),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in StoolLog.colors)
                  ChoiceChip(
                    label: Text(c),
                    selected: _color == c,
                    onSelected: (_) => setState(() => _color = c),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('특이사항(해당하면 선택)', style: text.titleSmall),
            Wrap(
              spacing: 8,
              children: [
                for (final f in StoolLog.flagOptions)
                  FilterChip(
                    label: Text(f),
                    selected: _flags.contains(f),
                    onSelected: (v) => setState(
                      () => v ? _flags.add(f) : _flags.remove(f),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_photo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(_photo),
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(_photo.isEmpty ? '사진 추가' : '사진 바꾸기'),
                ),
                if (_photo.isNotEmpty)
                  IconButton(
                    onPressed: () => setState(() => _photo = ''),
                    icon: const Icon(Icons.close),
                    tooltip: '사진 지우기',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memo,
              decoration: const InputDecoration(
                labelText: '메모(선택) 예: 새 간식 먹음',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    widget.initial.copyWith(
                      date: _date,
                      score: _score,
                      color: _color,
                      flags: StoolLog.flagOptions
                          .where(_flags.contains)
                          .toList(),
                      memo: _memo.text.trim(),
                      photo: _photo,
                    ),
                  ),
                  child: const Text('저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

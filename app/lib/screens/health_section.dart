import 'package:flutter/material.dart';

import '../backup/file_download.dart';
import '../backup/ics.dart';
import '../data/record_store.dart';
import '../models/health_record.dart';
import '../models/visit.dart' show ddayText;
import 'diary_edit_screen.dart' show todayString;

/// 예방접종·예방약: 다가오는 일정(지연 포함) + 전체 기록.
class HealthSection extends StatefulWidget {
  const HealthSection({
    super.key,
    required this.store,
    required this.authorName,
    required this.onChanged,
  });
  final RecordStore<HealthRecord> store;
  final String authorName;
  final VoidCallback onChanged; // 변경 후 홈의 다가오는 일정 갱신용

  @override
  State<HealthSection> createState() => _HealthSectionState();
}

class _HealthSectionState extends State<HealthSection> {
  List<HealthRecord> _all = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final list = await widget.store.load()
        ..sort((a, b) => b.date.compareTo(a.date));
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

  HealthRecord _blank({String kind = '종합백신', String name = ''}) {
    final now = DateTime.now();
    final today = todayString(now);
    return HealthRecord(
      id: now.microsecondsSinceEpoch.toString(),
      kind: kind,
      name: name,
      date: today,
      nextDate: HealthRecord.suggestNext(kind, today),
      author: widget.authorName,
      createdAt: now.millisecondsSinceEpoch,
    );
  }

  Future<void> _edit(HealthRecord r, {required bool isNew}) async {
    final result = await showModalBottomSheet<HealthRecord>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HealthForm(initial: r, isNew: isNew),
    );
    if (result == null) return;
    try {
      await widget.store.save(result);
      await _reload();
      widget.onChanged();
    } catch (e) {
      _toast('저장하지 못했습니다. $e');
    }
  }

  Future<void> _delete(HealthRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('기록 삭제'),
        content: Text('${r.title} (${r.date}) 기록을 삭제할까요?'),
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
      await widget.store.delete(r.id);
      await _reload();
      widget.onChanged();
    } catch (e) {
      _toast('삭제하지 못했습니다. $e');
    }
  }

  Future<void> _addToCalendar(HealthRecord r) async {
    try {
      await downloadTextFile(
        'chio-${r.nextDate}.ics',
        buildIcs(
          title: '치오 ${r.title} 예정',
          date: r.nextDate,
          description: [r.place, r.memo].where((e) => e.isNotEmpty).join(' / '),
          uid: 'health-${r.id}-${r.nextDate}',
        ),
        mime: 'text/calendar',
      );
      _toast('일정 파일을 내려받았어요. 파일을 열면 캘린더에 추가돼요.');
    } catch (e) {
      _toast('일정 파일을 만들지 못했습니다. $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('기록을 불러오지 못했습니다.\n$_error'));
    final today = DateTime.now();
    final due = HealthRecord.due(_all, today, withinDays: 30);
    final todayStr = todayString(today);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (_all.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(
                    '아직 접종·예방약 기록이 없어요.\n아래 버튼으로 기록하면 다음 일정을 알려 드려요.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (due.isNotEmpty) ...[
              Text('다가오는 일정', style: text.titleSmall),
              const SizedBox(height: 4),
              for (final r in due)
                Card(
                  color: r.nextDate.compareTo(todayStr) < 0
                      ? scheme.errorContainer
                      : scheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(r.title, style: text.titleMedium),
                            ),
                            Text(
                              ddayText(r.nextDate, today),
                              style: text.titleMedium,
                            ),
                          ],
                        ),
                        Text(
                          '예정 ${r.nextDate}${r.nextDate.compareTo(todayStr) < 0 ? ' (지났어요)' : ''}  ·  마지막 ${r.date}',
                          style: text.bodySmall,
                        ),
                        Wrap(
                          spacing: 4,
                          children: [
                            TextButton.icon(
                              onPressed: () => _edit(
                                _blank(
                                  kind: r.kind,
                                  name: r.name,
                                ).copyWith(place: r.place),
                                isNew: true,
                              ),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('완료 기록'),
                            ),
                            TextButton.icon(
                              onPressed: () => _addToCalendar(r),
                              icon: const Icon(Icons.event, size: 18),
                              label: const Text('캘린더에 추가'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
            if (_all.isNotEmpty) Text('전체 기록', style: text.titleSmall),
            for (final r in _all)
              Card(
                child: ListTile(
                  onTap: () => _edit(r, isNew: false),
                  leading: CircleAvatar(
                    child: Icon(
                      HealthRecord.vaccineKinds.contains(r.kind)
                          ? Icons.vaccines_outlined
                          : Icons.medication_outlined,
                    ),
                  ),
                  title: Text(r.title),
                  subtitle: Text(
                    [
                      r.date,
                      if (r.nextDate.isNotEmpty) '다음 ${r.nextDate}',
                      if (r.place.isNotEmpty) r.place,
                      if (r.memo.isNotEmpty) r.memo,
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '삭제',
                    onPressed: () => _delete(r),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'health-fab',
        onPressed: () => _edit(_blank(), isNew: true),
        icon: const Icon(Icons.add),
        label: const Text('접종·약 기록'),
      ),
    );
  }
}

class _HealthForm extends StatefulWidget {
  const _HealthForm({required this.initial, required this.isNew});
  final HealthRecord initial;
  final bool isNew;

  @override
  State<_HealthForm> createState() => _HealthFormState();
}

class _HealthFormState extends State<_HealthForm> {
  late String _kind = widget.initial.kind;
  late String _date = widget.initial.date;
  late String _next = widget.initial.nextDate;
  bool _nextTouched = false; // 직접 고른 다음 예정일은 자동 제안으로 덮어쓰지 않는다
  late final _name = TextEditingController(text: widget.initial.name);
  late final _place = TextEditingController(text: widget.initial.place);
  late final _memo = TextEditingController(text: widget.initial.memo);

  @override
  void initState() {
    super.initState();
    _nextTouched = !widget.isNew && widget.initial.nextDate.isNotEmpty;
  }

  @override
  void dispose() {
    _name.dispose();
    _place.dispose();
    _memo.dispose();
    super.dispose();
  }

  void _suggest() {
    if (!_nextTouched) _next = HealthRecord.suggestNext(_kind, _date);
  }

  Future<String?> _pick(String current, {required bool past}) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(current) ?? now,
      firstDate: DateTime(2000),
      lastDate: past ? now : DateTime(now.year + 5),
    );
    return d == null ? null : todayString(d);
  }

  @override
  Widget build(BuildContext context) {
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
            Text(
              widget.isNew ? '접종·예방약 기록' : '기록 수정',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final k in HealthRecord.kinds)
                  ChoiceChip(
                    label: Text(k),
                    selected: _kind == k,
                    onSelected: (_) => setState(() {
                      _kind = k;
                      _suggest();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '이름(선택) 예: 5종 2차, 넥스가드',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text('한 날 $_date'),
                    onPressed: () async {
                      final d = await _pick(_date, past: true);
                      if (d != null) {
                        setState(() {
                          _date = d;
                          _suggest();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event_repeat, size: 18),
                    label: Text(_next.isEmpty ? '다음 예정일(선택)' : '다음 $_next'),
                    onPressed: () async {
                      final d = await _pick(_next, past: false);
                      if (d != null) {
                        setState(() {
                          _next = d;
                          _nextTouched = true;
                        });
                      }
                    },
                  ),
                ),
                if (_next.isNotEmpty)
                  IconButton(
                    onPressed: () => setState(() {
                      _next = '';
                      _nextTouched = true;
                    }),
                    icon: const Icon(Icons.close),
                    tooltip: '예정일 지우기',
                  ),
              ],
            ),
            if (!_nextTouched && _next.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '종류에 따른 일반적인 간격으로 제안한 날짜예요. 병원 안내에 맞게 바꿔 주세요.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _place,
              decoration: const InputDecoration(
                labelText: '병원·장소(선택)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memo,
              decoration: const InputDecoration(
                labelText: '메모(선택)',
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
                      kind: _kind,
                      name: _name.text.trim(),
                      date: _date,
                      nextDate: _next,
                      place: _place.text.trim(),
                      memo: _memo.text.trim(),
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

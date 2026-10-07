import 'package:flutter/material.dart';

import '../models/daily_log.dart';

String _hhmm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

Future<String?> _pickTime(BuildContext context, String current) async {
  final parts = current.split(':');
  final initial = parts.length == 2
      ? TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9,
          minute: int.tryParse(parts[1]) ?? 0,
        )
      : TimeOfDay.now();
  final t = await showTimePicker(context: context, initialTime: initial);
  return t == null ? null : _hhmm(t);
}

/// 산책 입력 카드: 여러 번 추가·수정·삭제.
class WalkSection extends StatelessWidget {
  const WalkSection({super.key, required this.walks, required this.onChanged});
  final List<WalkLog> walks;
  final ValueChanged<List<WalkLog>> onChanged;

  Future<void> _edit(BuildContext context, {int? index}) async {
    final r = await showModalBottomSheet<WalkLog>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WalkForm(
        initial: index == null
            ? WalkLog(time: _hhmm(TimeOfDay.now()))
            : walks[index],
      ),
    );
    if (r == null) return;
    final next = [...walks];
    if (index == null) {
      next.add(r);
    } else {
      next[index] = r;
    }
    next.sort((a, b) => a.time.compareTo(b.time));
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '🚶 산책',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (walks.isNotEmpty) Text('  ${walks.length}회'),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('산책 추가'),
                ),
              ],
            ),
            for (var i = 0; i < walks.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('${i + 1}회  ${walks[i].summary}'),
                subtitle: walks[i].memo.isEmpty ? null : Text(walks[i].memo),
                onTap: () => _edit(context, index: i),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: '삭제',
                  onPressed: () => onChanged([...walks]..removeAt(i)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WalkForm extends StatefulWidget {
  const _WalkForm({required this.initial});
  final WalkLog initial;

  @override
  State<_WalkForm> createState() => _WalkFormState();
}

class _WalkFormState extends State<_WalkForm> {
  late String _time = widget.initial.time;
  late String _poop = widget.initial.poop;
  late final _place = TextEditingController(text: widget.initial.place);
  late final _minutes = TextEditingController(
    text: widget.initial.minutes == 0 ? '' : '${widget.initial.minutes}',
  );
  late final _memo = TextEditingController(text: widget.initial.memo);

  @override
  void dispose() {
    _place.dispose();
    _minutes.dispose();
    _memo.dispose();
    super.dispose();
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
            Text('산책 기록', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule, size: 18),
              label: Text(_time.isEmpty ? '시각 선택' : _time),
              onPressed: () async {
                final t = await _pickTime(context, _time);
                if (t != null) setState(() => _time = t);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _place,
              decoration: const InputDecoration(
                labelText: '장소 (예: 한강공원)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '산책 시간(분)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text('배변'),
            Wrap(
              spacing: 8,
              children: [
                for (final o in WalkLog.poopOptions)
                  ChoiceChip(
                    label: Text(o),
                    selected: _poop == o,
                    onSelected: (v) => setState(() => _poop = v ? o : ''),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memo,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '기타',
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
                    WalkLog(
                      time: _time,
                      place: _place.text.trim(),
                      minutes: int.tryParse(_minutes.text.trim()) ?? 0,
                      poop: _poop,
                      memo: _memo.text.trim(),
                    ),
                  ),
                  child: const Text('확인'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 추가 급여(간식·영양제 등) 입력 카드. 기본 급여는 기록하지 않는다.
class FeedSection extends StatelessWidget {
  const FeedSection({super.key, required this.feeds, required this.onChanged});
  final List<FeedLog> feeds;
  final ValueChanged<List<FeedLog>> onChanged;

  Future<void> _edit(BuildContext context, {int? index}) async {
    final r = await showModalBottomSheet<FeedLog>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FeedForm(
        initial: index == null
            ? FeedLog(time: _hhmm(TimeOfDay.now()))
            : feeds[index],
      ),
    );
    if (r == null) return;
    final next = [...feeds];
    if (index == null) {
      next.add(r);
    } else {
      next[index] = r;
    }
    next.sort((a, b) => a.time.compareTo(b.time));
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '🍖 추가 급여',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (feeds.isNotEmpty) Text('  ${feeds.length}건'),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('추가'),
                ),
              ],
            ),
            if (feeds.isEmpty)
              const Text(
                '기본 급여 외에 준 간식·영양제만 적어요.',
                style: TextStyle(fontSize: 12),
              ),
            for (var i = 0; i < feeds.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(feeds[i].summary),
                subtitle: feeds[i].memo.isEmpty ? null : Text(feeds[i].memo),
                onTap: () => _edit(context, index: i),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: '삭제',
                  onPressed: () => onChanged([...feeds]..removeAt(i)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeedForm extends StatefulWidget {
  const _FeedForm({required this.initial});
  final FeedLog initial;

  @override
  State<_FeedForm> createState() => _FeedFormState();
}

class _FeedFormState extends State<_FeedForm> {
  late String _time = widget.initial.time;
  late final _kind = TextEditingController(text: widget.initial.kind);
  late final _amount = TextEditingController(text: widget.initial.amount);
  late final _memo = TextEditingController(text: widget.initial.memo);

  @override
  void dispose() {
    _kind.dispose();
    _amount.dispose();
    _memo.dispose();
    super.dispose();
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
            Text('추가 급여 기록', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule, size: 18),
              label: Text(_time.isEmpty ? '시각 선택' : _time),
              onPressed: () async {
                final t = await _pickTime(context, _time);
                if (t != null) setState(() => _time = t);
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final k in FeedLog.kindSuggestions)
                  ActionChip(
                    label: Text(k),
                    onPressed: () => setState(() => _kind.text = k),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _kind,
              decoration: const InputDecoration(
                labelText: '종류 (예: 닭가슴살 간식)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              decoration: const InputDecoration(
                labelText: '양 (예: 3개, 한 스푼, 20g)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memo,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '기타',
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
                    FeedLog(
                      time: _time,
                      kind: _kind.text.trim(),
                      amount: _amount.text.trim(),
                      memo: _memo.text.trim(),
                    ),
                  ),
                  child: const Text('확인'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../data/change_source.dart';
import '../data/record_store.dart';
import '../models/weight_log.dart';
import 'diary_edit_screen.dart' show todayString;

/// 체중 기록: 그래프 + 목록 + 추가·수정·삭제.
class WeightSection extends StatefulWidget {
  const WeightSection({
    super.key,
    required this.store,
    required this.authorName,
  });
  final RecordStore<WeightLog> store;
  final String authorName;

  @override
  State<WeightSection> createState() => _WeightSectionState();
}

class _WeightSectionState extends State<WeightSection> {
  List<WeightLog> _asc = [];
  bool _loading = true;
  String? _error;

  ChangeWatcher? _watcher;

  @override
  void initState() {
    super.initState();
    _reload();
    _watcher = ChangeWatcher(widget.store, _reload); // 다른 가족이 기록한 체중을 바로 반영
  }

  @override
  void dispose() {
    _watcher?.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final list = await widget.store.load()
        ..sort((a, b) => a.date.compareTo(b.date));
      if (mounted) {
        setState(() {
          _asc = list;
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

  Future<void> _edit([WeightLog? w]) async {
    final result = await showModalBottomSheet<WeightLog>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WeightForm(
        initial:
            w ??
            WeightLog(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              date: todayString(),
              kg: _asc.isEmpty ? 0 : _asc.last.kg,
              author: widget.authorName,
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
        isNew: w == null,
      ),
    );
    if (result == null) return;
    try {
      await widget.store.save(result);
      await _reload();
    } catch (e) {
      _toast('저장하지 못했습니다. $e');
    }
  }

  Future<void> _delete(WeightLog w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('체중 기록 삭제'),
        content: Text('${w.date}  ${WeightLog.fmt(w.kg)}kg 기록을 삭제할까요?'),
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
      await widget.store.delete(w.id);
      await _reload();
    } catch (e) {
      _toast('삭제하지 못했습니다. $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('체중 기록을 불러오지 못했습니다.\n$_error'));
    }
    final change = WeightLog.latestChange(_asc);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (_asc.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(
                    '아직 체중 기록이 없어요.\n아래 버튼으로 첫 기록을 남겨 보세요.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${WeightLog.fmt(_asc.last.kg)}kg',
                            style: text.headlineMedium,
                          ),
                          const SizedBox(width: 8),
                          if (change != null)
                            Text(
                              '${change > 0 ? '+' : ''}${WeightLog.fmt(change)}kg',
                              style: text.titleSmall?.copyWith(
                                color: change.abs() >= 0.5
                                    ? Theme.of(context).colorScheme.error
                                    : null,
                              ),
                            ),
                          const Spacer(),
                          Text(_asc.last.date, style: text.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 160,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: WeightChartPainter(
                            points: _asc.length > 24
                                ? _asc.sublist(_asc.length - 24)
                                : _asc,
                            lineColor: Theme.of(context).colorScheme.primary,
                            gridColor: Theme.of(context)
                                .colorScheme
                                .outlineVariant,
                            textColor: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (change != null && change.abs() >= 0.5)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '직전 기록보다 0.5kg 이상 변했어요. 계속되면 병원 상담을 권해요.',
                            style: text.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              for (final w in _asc.reversed)
                Card(
                  child: ListTile(
                    title: Text('${WeightLog.fmt(w.kg)}kg   ${w.date}'),
                    subtitle:
                        [w.memo, w.author].where((e) => e.isNotEmpty).isEmpty
                        ? null
                        : Text(
                            [
                              w.memo,
                              w.author,
                            ].where((e) => e.isNotEmpty).join(' · '),
                          ),
                    onTap: () => _edit(w),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: '삭제',
                      onPressed: () => _delete(w),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'weight-fab',
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('체중 기록'),
      ),
    );
  }
}

class _WeightForm extends StatefulWidget {
  const _WeightForm({required this.initial, required this.isNew});
  final WeightLog initial;
  final bool isNew;

  @override
  State<_WeightForm> createState() => _WeightFormState();
}

class _WeightFormState extends State<_WeightForm> {
  late String _date = widget.initial.date;
  late final _kg = TextEditingController(
    text: widget.initial.kg == 0 ? '' : WeightLog.fmt(widget.initial.kg),
  );
  late final _memo = TextEditingController(text: widget.initial.memo);
  String? _error;

  @override
  void dispose() {
    _kg.dispose();
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
            Text(
              widget.isNew ? '체중 기록' : '체중 수정',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
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
            TextField(
              controller: _kg,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: '체중(kg)',
                border: const OutlineInputBorder(),
                errorText: _error,
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
                  onPressed: () {
                    final kg = double.tryParse(
                      _kg.text.trim().replaceAll(',', '.'),
                    );
                    if (kg == null || kg <= 0 || kg > 100) {
                      setState(() => _error = '0보다 크고 100 이하인 숫자로 입력해 주세요.');
                      return;
                    }
                    Navigator.pop(
                      context,
                      widget.initial.copyWith(
                        date: _date,
                        kg: kg,
                        memo: _memo.text.trim(),
                      ),
                    );
                  },
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

/// 날짜 간격에 비례해 점을 찍는 단순 꺾은선 그래프.
class WeightChartPainter extends CustomPainter {
  WeightChartPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
  });
  final List<WeightLog> points; // 날짜 오름차순
  final Color lineColor;
  final Color gridColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const left = 36.0, right = 8.0, top = 8.0, bottom = 20.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    var minKg = points.map((e) => e.kg).reduce((a, b) => a < b ? a : b);
    var maxKg = points.map((e) => e.kg).reduce((a, b) => a > b ? a : b);
    if (maxKg - minKg < 0.4) {
      final mid = (maxKg + minKg) / 2;
      minKg = mid - 0.2;
      maxKg = mid + 0.2;
    }
    final pad = (maxKg - minKg) * 0.1;
    minKg -= pad;
    maxKg += pad;

    final t0 =
        DateTime.tryParse(points.first.date)?.millisecondsSinceEpoch ?? 0;
    final t1 = DateTime.tryParse(points.last.date)?.millisecondsSinceEpoch ?? 0;
    double x(WeightLog p) {
      if (points.length == 1 || t1 == t0) return left + w / 2;
      final t = DateTime.tryParse(p.date)?.millisecondsSinceEpoch ?? t0;
      return left + w * (t - t0) / (t1 - t0);
    }

    double y(double kg) => top + h * (1 - (kg - minKg) / (maxKg - minKg));

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    void label(String s, Offset o, {TextAlign align = TextAlign.left}) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(color: textColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = align == TextAlign.right ? o.dx - tp.width : o.dx;
      tp.paint(canvas, Offset(dx, o.dy - tp.height / 2));
    }

    for (final kg in [minKg + pad, (minKg + maxKg) / 2, maxKg - pad]) {
      canvas.drawLine(
        Offset(left, y(kg)),
        Offset(size.width - right, y(kg)),
        grid,
      );
      label(
        WeightLog.fmt(double.parse(kg.toStringAsFixed(1))),
        Offset(left - 4, y(kg)),
        align: TextAlign.right,
      );
    }
    label(
      points.first.date.length >= 10
          ? points.first.date.substring(5)
          : points.first.date,
      Offset(left, size.height - 8),
    );
    if (points.length > 1) {
      label(
        points.last.date.length >= 10
            ? points.last.date.substring(5)
            : points.last.date,
        Offset(size.width - right, size.height - 8),
        align: TextAlign.right,
      );
    }

    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(x(points[i]), y(points[i].kg));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, line);
    final dot = Paint()..color = lineColor;
    for (final p in points) {
      canvas.drawCircle(Offset(x(p), y(p.kg)), 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant WeightChartPainter old) =>
      old.points != points || old.lineColor != lineColor;
}

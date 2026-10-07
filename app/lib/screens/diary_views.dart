import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/diary_entry.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 월 달력: 일기가 있는 날에 기분 이모지(없으면 점)를 보여 준다.
class DiaryCalendarView extends StatefulWidget {
  const DiaryCalendarView({
    super.key,
    required this.entries,
    required this.onOpen,
    required this.onWrite,
  });
  final List<DiaryEntry> entries;
  final void Function(DiaryEntry) onOpen;
  final void Function(String date) onWrite;

  @override
  State<DiaryCalendarView> createState() => _DiaryCalendarViewState();
}

class _DiaryCalendarViewState extends State<DiaryCalendarView> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _selected;

  void _move(int delta) => setState(() {
    _month = DateTime(_month.year, _month.month + delta);
    _selected = null;
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final byDate = <String, List<DiaryEntry>>{};
    for (final e in widget.entries) {
      byDate.putIfAbsent(e.date, () => []).add(e);
    }
    final first = DateTime(_month.year, _month.month);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday % 7; // 일요일 시작
    final today = _ymd(DateTime.now());
    final monthCount = [
      for (var d = 1; d <= days; d++)
        if (byDate.containsKey(_ymd(DateTime(_month.year, _month.month, d)))) d,
    ].length;
    final selectedEntries = _selected == null
        ? const <DiaryEntry>[]
        : (byDate[_selected] ?? const <DiaryEntry>[]);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => _move(-1),
              icon: const Icon(Icons.chevron_left),
              tooltip: '이전 달',
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${_month.year}년 ${_month.month}월 · 기록한 날 $monthCount일',
                  style: text.titleMedium,
                ),
              ),
            ),
            IconButton(
              onPressed: () => _move(1),
              icon: const Icon(Icons.chevron_right),
              tooltip: '다음 달',
            ),
          ],
        ),
        Row(
          children: [
            for (final w in const ['일', '월', '화', '수', '목', '금', '토'])
              Expanded(
                child: Center(child: Text(w, style: text.bodySmall)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < ((lead + days) / 7).ceil(); row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: Builder(
                    builder: (_) {
                      final d = row * 7 + col - lead + 1;
                      if (d < 1 || d > days) return const SizedBox(height: 52);
                      final key = _ymd(DateTime(_month.year, _month.month, d));
                      final list = byDate[key];
                      final mood = list == null
                          ? ''
                          : list
                                .map((e) => e.mood)
                                .firstWhere((m) => m.isNotEmpty, orElse: () => '');
                      final sel = _selected == key;
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _selected = key),
                        child: Container(
                          height: 52,
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: sel ? scheme.primaryContainer : null,
                            border: key == today
                                ? Border.all(color: scheme.primary)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('$d', style: text.bodySmall),
                              if (list != null)
                                mood.isNotEmpty
                                    ? Text(mood, style: const TextStyle(fontSize: 16))
                                    : Icon(
                                        Icons.circle,
                                        size: 8,
                                        color: scheme.primary,
                                      ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        if (_selected != null) ...[
          const Divider(height: 24),
          Text(_selected!, style: text.titleSmall),
          if (selectedEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('이 날은 일기가 없어요.'),
            ),
          for (final e in selectedEntries)
            Card(
              child: ListTile(
                onTap: () => widget.onOpen(e),
                leading: Text(
                  e.mood.isEmpty ? '📖' : e.mood,
                  style: const TextStyle(fontSize: 22),
                ),
                title: Text(
                  e.body.isEmpty ? '(내용 없음)' : e.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(e.author),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => widget.onWrite(_selected!),
            icon: const Icon(Icons.edit),
            label: const Text('이 날 일기 쓰기'),
          ),
        ],
      ],
    );
  }
}

/// 모든 일기 사진을 최신순 격자로 모아 보여 준다. 사진을 누르면 그 일기를 연다.
class DiaryGalleryView extends StatelessWidget {
  const DiaryGalleryView({
    super.key,
    required this.entries,
    required this.onOpen,
  });
  final List<DiaryEntry> entries;
  final void Function(DiaryEntry) onOpen;

  @override
  Widget build(BuildContext context) {
    final items = <(DiaryEntry, String)>[
      for (final e in entries)
        for (final p in e.photos) (e, p),
    ];
    if (items.isEmpty) {
      return const Center(child: Text('아직 일기에 올린 사진이 없어요.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final (e, p) = items[i];
        return InkWell(
          onTap: () => onOpen(e),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                base64Decode(p),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: 300,
                errorBuilder: (_, _, _) =>
                    const Center(child: Icon(Icons.broken_image_outlined)),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    e.date,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

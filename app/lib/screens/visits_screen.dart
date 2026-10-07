import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/visit_store.dart';
import '../models/place.dart';
import '../models/visit.dart';
import 'diary_edit_screen.dart' show todayString;
import 'visit_edit_screen.dart';

/// 병원·미용 탭: 다가오는 예약 + 지난 기록(월별) + 지출 요약.
class VisitsScreen extends StatefulWidget {
  const VisitsScreen({
    super.key,
    required this.store,
    required this.visits,
    required this.places,
    required this.authorName,
    required this.onChanged,
    required this.onAddPlace,
  });
  final VisitStore store;
  final List<Visit> visits;
  final List<Place> places;
  final String authorName;
  final Future<void> Function() onChanged; // 저장·삭제 후 목록 새로고침
  final Future<void> Function(Place) onAddPlace; // 직접 입력한 장소를 프로필에 추가

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  String _filter = '전체';
  static final _won = NumberFormat('#,###');

  Future<void> _open(Visit v, {required bool isNew}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VisitEditScreen(
          visit: v,
          isNew: isNew,
          places: widget.places,
          store: widget.store,
          onAddPlace: widget.onAddPlace,
          onSave: (e) async {
            await widget.store.save(e);
            await widget.onChanged();
          },
          onDelete: isNew
              ? null
              : () async {
                  await widget.store.delete(v.id);
                  await widget.onChanged();
                },
        ),
      ),
    );
  }

  void _add() {
    final now = DateTime.now();
    _open(
      Visit(
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
    final today = todayString();
    final filtered = widget.visits
        .where((v) => _filter == '전체' || v.type == _filter)
        .toList();
    final upcoming = upcomingVisits(filtered, today);
    final past = filtered.where((v) => !upcoming.contains(v)).toList();

    final year = today.substring(0, 4);
    final month = today.substring(0, 7);
    int sum(bool Function(Visit) f) => widget.visits
        .where((v) => v.status == '완료')
        .where(f)
        .fold(0, (a, v) => a + v.amount);
    final yearSum = sum((v) => v.date.startsWith(year));
    final monthSum = sum((v) => v.date.startsWith(month));

    final children = <Widget>[
      Wrap(
        spacing: 8,
        children: [
          for (final f in ['전체', ...Visit.types])
            ChoiceChip(
              label: Text(f),
              selected: _filter == f,
              onSelected: (_) => setState(() => _filter = f),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        '이번 달 ${_won.format(monthSum)}원 · 올해 ${_won.format(yearSum)}원',
        style: text.bodySmall,
      ),
    ];
    if (upcoming.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text('다가오는 예약', style: text.titleSmall),
        ),
      );
      for (final v in upcoming) {
        children.add(
          _VisitCard(
            visit: v,
            onTap: () => _open(v, isNew: false),
            highlight: true,
          ),
        );
      }
    }
    String lastMonth = '';
    for (final v in past) {
      final m = v.date.length >= 7 ? v.date.substring(0, 7) : v.date;
      if (m != lastMonth) {
        lastMonth = m;
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(m, style: text.titleSmall),
          ),
        );
      }
      children.add(_VisitCard(visit: v, onTap: () => _open(v, isNew: false)));
    }
    if (filtered.isEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(
            child: Text(
              '아직 기록이 없어요.\n아래 버튼으로 병원·미용 기록을 추가하세요.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: widget.onChanged,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: children,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('기록 추가'),
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({
    required this.visit,
    required this.onTap,
    this.highlight = false,
  });
  final Visit visit;
  final VoidCallback onTap;
  final bool highlight;

  static final _won = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (visit.type) {
      '병원' => Icons.local_hospital_outlined,
      '미용' => Icons.content_cut,
      _ => Icons.pets_outlined,
    };
    final dday = visit.isUpcoming ? ddayText(visit.date, DateTime.now()) : '';
    return Card(
      color: highlight ? scheme.primaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(visit.placeName.isEmpty ? visit.type : visit.placeName),
        subtitle: Text(
          [
            '${visit.date}${visit.time.isEmpty ? '' : ' ${visit.time}'}',
            if (visit.detail.isNotEmpty) visit.detail,
          ].join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: visit.detail.isNotEmpty,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (dday.isNotEmpty) Text(dday, style: text.titleSmall),
            if (visit.status == '예약' && dday.isEmpty) const Text('예약'),
            if (visit.amount > 0)
              Text('${_won.format(visit.amount)}원', style: text.bodySmall),
            if (visit.photoCount > 0)
              Text('📷 ${visit.photoCount}', style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

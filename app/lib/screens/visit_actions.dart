import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../backup/file_download.dart';
import '../backup/ics.dart';

import '../data/visit_store.dart';
import '../models/place.dart';
import '../models/visit.dart';
import 'diary_edit_screen.dart' show todayString;
import 'visit_edit_screen.dart';

/// 방문 기록 1건에 대한 공통 동작(확인 창, 수정, 삭제, 완료 처리).
/// 홈의 '다가오는 예약'과 병원·미용 목록이 같은 동작을 쓰도록 모아 둔다.
class VisitActions {
  const VisitActions({
    required this.store,
    required this.places,
    required this.authorName,
    required this.onChanged,
    required this.onAddPlace,
  });

  final VisitStore store;
  final List<Place> places;
  final String authorName;
  final Future<void> Function() onChanged;
  final Future<void> Function(Place) onAddPlace;

  static final _won = NumberFormat('#,###');

  void _toast(BuildContext context, String m) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> add(BuildContext context) {
    final now = DateTime.now();
    return openEditor(
      context,
      Visit(
        id: now.microsecondsSinceEpoch.toString(),
        date: todayString(now),
        author: authorName,
        createdAt: now.millisecondsSinceEpoch,
      ),
      isNew: true,
    );
  }

  Future<void> openEditor(BuildContext context, Visit v, {bool isNew = false}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VisitEditScreen(
          visit: v,
          isNew: isNew,
          places: places,
          store: store,
          onAddPlace: onAddPlace,
          onSave: (e) async {
            await store.save(e);
            await onChanged();
          },
          onDelete: isNew
              ? null
              : () async {
                  await store.delete(v.id);
                  await onChanged();
                },
        ),
      ),
    );
  }

  /// 확인 후 삭제. 삭제했으면 true.
  Future<bool> confirmDelete(BuildContext context, Visit v) async {
    final name = v.placeName.isEmpty ? v.type : v.placeName;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('기록 삭제'),
        content: Text('$name (${v.date}) 기록을 삭제할까요?\n첨부 사진도 함께 삭제됩니다.'),
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
      await store.delete(v.id);
      await onChanged();
      return true;
    } catch (e) {
      if (context.mounted) _toast(context, '삭제하지 못했습니다. $e');
      return false;
    }
  }

  /// 예약을 완료로 바꾼다. 목록은 사진 없이 불러오므로, 사진을 먼저 읽어 와서 함께 저장해야
  /// 기존 첨부 사진이 지워지지 않는다.
  Future<void> markDone(BuildContext context, Visit v) async {
    try {
      final photos = await store.loadPhotos(v.id);
      await store.save(v.copyWith(status: '완료', photos: photos));
      await onChanged();
    } catch (e) {
      if (context.mounted) _toast(context, '완료 처리하지 못했습니다. $e');
    }
  }

  /// 예약을 폰 캘린더 일정(.ics)으로 내려받는다. 캘린더 앱이 하루 전·1시간 전에 알려 준다.
  Future<void> addToCalendar(BuildContext context, Visit v) async {
    try {
      await downloadTextFile(
        'chio-${v.date}.ics',
        buildIcs(
          title:
              '치오 ${v.type} 예약${v.placeName.isEmpty ? '' : ' - ${v.placeName}'}',
          date: v.date,
          time: v.time,
          description: [
            v.detail,
            v.memo,
          ].where((e) => e.isNotEmpty).join(' / '),
          location: v.placeName,
          uid: 'visit-${v.id}-${v.date}',
        ),
        mime: 'text/calendar',
      );
      if (!context.mounted) return;
      _toast(context, '일정 파일을 내려받았어요. 파일을 열면 캘린더에 추가돼요.');
    } catch (e) {
      if (!context.mounted) return;
      _toast(context, '일정 파일을 만들지 못했습니다. $e');
    }
  }

  /// 눌렀을 때 열리는 확인 창: 내용 + 수정·삭제·(예약이면) 완료 처리.
  Future<void> showSheet(BuildContext context, Visit v) {
    final text = Theme.of(context).textTheme;
    final dday = v.isUpcoming ? ddayText(v.date, DateTime.now()) : '';
    Widget row(String label, String value) => value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 76, child: Text(label, style: text.bodySmall)),
                Expanded(child: Text(value)),
              ],
            ),
          );
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      v.placeName.isEmpty ? v.type : v.placeName,
                      style: text.titleLarge,
                    ),
                  ),
                  if (dday.isNotEmpty) Text(dday, style: text.titleMedium),
                ],
              ),
              const SizedBox(height: 4),
              Text('${v.type} · ${v.status}', style: text.bodySmall),
              const SizedBox(height: 8),
              row('일시', '${v.date}${v.time.isEmpty ? '' : ' ${v.time}'}'),
              row('금액', v.amount > 0 ? '${_won.format(v.amount)}원' : ''),
              row(v.type == '병원' ? '증상·진단' : '내용', v.detail),
              row('처방·처치', v.prescription),
              row('메모', v.memo),
              row('다음 예약', v.nextDate),
              row(
                '사진',
                v.photoCount > 0 ? '${v.photoCount}장 (수정 화면에서 보기)' : '',
              ),
              row('작성자', v.author),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(c);
                      openEditor(context, v);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('수정'),
                  ),
                  if (v.isUpcoming)
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.pop(c);
                        markDone(context, v);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('완료 처리'),
                    ),
                  if (v.isUpcoming)
                    OutlinedButton.icon(
                      onPressed: () => addToCalendar(context, v),
                      icon: const Icon(Icons.event),
                      label: const Text('캘린더에 추가'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(c);
                      await confirmDelete(context, v);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('삭제'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

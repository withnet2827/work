import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/visit_store.dart';
import '../models/attachment.dart';
import '../models/place.dart';
import '../models/visit.dart';
import 'attachment_viewer_screen.dart';
import 'diary_edit_screen.dart' show todayString;
import '../util/photo_compress.dart';

/// 방문(병원·미용 등) 기록 작성·수정. 사진은 열 때 따로 불러온다.
class VisitEditScreen extends StatefulWidget {
  const VisitEditScreen({
    super.key,
    required this.visit,
    required this.isNew,
    required this.places,
    required this.store,
    required this.onSave,
    required this.onAddPlace,
    this.onDelete,
  });
  final Visit visit;
  final bool isNew;
  final List<Place> places;
  final VisitStore store;
  final Future<void> Function(Visit) onSave;

  /// 직접 입력한 장소를 프로필 장소 목록에 추가한다.
  final Future<void> Function(Place) onAddPlace;
  final Future<void> Function()? onDelete;

  @override
  State<VisitEditScreen> createState() => _VisitEditScreenState();
}

class _VisitEditScreenState extends State<VisitEditScreen> {
  late String _type = widget.visit.type;
  late String _status = widget.visit.status;
  late String _date = widget.visit.date;
  late String _time = widget.visit.time;
  late String _nextDate = widget.visit.nextDate;
  late String _placeId = widget.visit.placeId;
  late final _placeName = TextEditingController(text: widget.visit.placeName);
  late final _amount = TextEditingController(
    text: widget.visit.amount == 0 ? '' : widget.visit.amount.toString(),
  );
  late final _detail = TextEditingController(text: widget.visit.detail);
  late final _prescription = TextEditingController(
    text: widget.visit.prescription,
  );
  late final _memo = TextEditingController(text: widget.visit.memo);
  bool _saveAsPlace = false; // 직접 입력한 장소를 프로필 장소로도 저장
  late bool _direct; // 등록된 장소가 아닌 곳을 직접 입력하는 중
  List<Attachment> _photos = [];
  bool _photosLoaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // 저장된 장소가 등록 목록과 일치하면 그 장소를 선택 상태로, 아니면 직접 입력 상태로 연다.
    final v = widget.visit;
    final match = widget.places.where(
      (p) =>
          p.id == v.placeId ||
          (v.placeId.isEmpty &&
              p.name == v.placeName &&
              v.placeName.isNotEmpty),
    );
    if (match.isNotEmpty) {
      _placeId = match.first.id;
      _direct = false;
    } else {
      _direct = v.placeName.isNotEmpty || _matchingPlaces.isEmpty;
    }
    if (widget.isNew) {
      _photosLoaded = true;
    } else {
      widget.store
          .loadPhotos(widget.visit.id)
          .then((p) {
            if (mounted) {
              setState(() {
                _photos = p;
                _photosLoaded = true;
              });
            }
          })
          .catchError((Object e) {
            if (mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('사진을 불러오지 못했습니다. $e')));
            }
          });
    }
  }

  @override
  void dispose() {
    for (final c in [_placeName, _amount, _detail, _prescription, _memo]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _placeCategory =>
      _type == '병원' ? '병원' : (_type == '미용' ? '미용실' : '');

  List<Place> get _matchingPlaces => widget.places
      .where((p) => _placeCategory.isEmpty || p.category == _placeCategory)
      .toList();

  Future<String?> _pickDate(String current) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(current) ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 3),
    );
    return d == null ? null : todayString(d);
  }

  Future<void> _pickTime() async {
    final parts = _time.split(':');
    final initial = parts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 9,
            minute: int.tryParse(parts[1]) ?? 0,
          )
        : const TimeOfDay(hour: 10, minute: 0);
    final t = await showTimePicker(context: context, initialTime: initial);
    if (t != null) {
      setState(
        () => _time =
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  Future<void> _addPhotos() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('앨범에서 선택 (여러 장 가능)'),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final picker = ImagePicker();
    final List<XFile> files;
    if (source == ImageSource.camera) {
      final x = await picker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 70,
      );
      files = [?x];
    } else {
      files = await picker.pickMultiImage(maxWidth: 1280, imageQuality: 70);
    }
    if (files.isEmpty || !mounted) return;

    var label = _type == '미용' ? '미용 전' : '영수증';
    final chosen = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('사진 ${files.length}장 구분'),
        content: DropdownButtonFormField<String>(
          initialValue: label,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            for (final l in Attachment.labels)
              DropdownMenuItem(value: l, child: Text(l)),
          ],
          onChanged: (v) => label = v ?? label,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, label),
            child: const Text('추가'),
          ),
        ],
      ),
    );
    if (chosen == null) return;
    final added = <Attachment>[];
    for (final f in files) {
      added.add(
        Attachment(
          id: '${DateTime.now().microsecondsSinceEpoch}-${added.length}',
          photoBase64: compressPhoto(await f.readAsBytes()),
          label: chosen,
          date: _date,
        ),
      );
    }
    if (mounted) setState(() => _photos = [..._photos, ...added]);
  }

  void _openPhoto(int i) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttachmentViewerScreen(
          attachments: _photos,
          initialIndex: i,
          canDelete: false,
          onDelete: (_) {},
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_date.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('날짜를 선택해 주세요.')));
      return;
    }
    final amount = int.tryParse(_amount.text.replaceAll(',', '').trim());
    if (_amount.text.trim().isNotEmpty && amount == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('금액은 숫자로 입력해 주세요.')));
      return;
    }
    setState(() => _busy = true);
    try {
      var placeId = _placeId;
      final name = _placeName.text.trim();
      if (_direct && name.isNotEmpty) {
        final category = _placeCategory.isEmpty ? '기타' : _placeCategory;
        final same = widget.places.where(
          (p) => p.name == name && p.category == category,
        );
        if (same.isNotEmpty) {
          // 이미 등록된 장소와 같으면 중복 등록하지 않고 연결만 한다.
          placeId = same.first.id;
        } else if (_saveAsPlace) {
          final place = Place(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            category: category,
            name: name,
          );
          await widget.onAddPlace(place);
          placeId = place.id;
        }
      }
      await widget.onSave(
        widget.visit.copyWith(
          type: _type,
          status: _status,
          date: _date,
          time: _time,
          placeId: placeId,
          placeName: name,
          amount: amount ?? 0,
          detail: _detail.text.trim(),
          prescription: _type == '병원' ? _prescription.text.trim() : '',
          memo: _memo.text.trim(),
          nextDate: _nextDate,
          photos: _photos,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장하지 못했습니다. $e')));
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('이 기록을 삭제할까요? 첨부 사진도 함께 삭제됩니다.'),
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
    setState(() => _busy = true);
    try {
      await widget.onDelete!();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('삭제하지 못했습니다. $e')));
      }
    }
  }

  Widget _compare() {
    Attachment? first(String l) {
      for (final p in _photos) {
        if (p.label == l) return p;
      }
      return null;
    }

    final before = first('미용 전');
    final after = first('미용 후');
    if (before == null || after == null) return const SizedBox.shrink();
    Widget cell(Attachment a) => Expanded(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.memory(
                base64Decode(a.photoBase64),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(a.label),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [cell(before), const SizedBox(width: 8), cell(after)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    final isHospital = _type == '병원';
    final matching = _matchingPlaces;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? '기록 추가' : '기록 수정'),
        actions: [
          if (!widget.isNew && widget.onDelete != null)
            IconButton(
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: '삭제',
            ),
          TextButton(
            onPressed: (_busy || !_photosLoaded) ? null : _save,
            child: const Text('저장'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: [
              for (final t in Visit.types)
                ButtonSegment(value: t, label: Text(t)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              if (!_direct) {
                _placeId = '';
                _placeName.clear();
              }
            }),
          ),
          gap,
          SegmentedButton<String>(
            segments: [
              for (final t in Visit.statuses)
                ButtonSegment(value: t, label: Text(t)),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
          gap,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(_date.isEmpty ? '날짜 선택' : _date),
                  onPressed: () async {
                    final d = await _pickDate(_date);
                    if (d != null) setState(() => _date = d);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(_time.isEmpty ? '시간(선택)' : _time),
                  onPressed: _pickTime,
                ),
              ),
            ],
          ),
          gap,
          Text('장소', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final p in matching)
                ChoiceChip(
                  avatar: const Icon(Icons.place_outlined, size: 16),
                  label: Text(p.name),
                  selected: !_direct && _placeId == p.id,
                  onSelected: (v) => setState(() {
                    _direct = false;
                    _placeId = v ? p.id : '';
                    _placeName.text = v ? p.name : '';
                  }),
                ),
              ChoiceChip(
                avatar: const Icon(Icons.edit_location_alt_outlined, size: 16),
                label: const Text('다른 곳 직접 입력'),
                selected: _direct,
                onSelected: (v) => setState(() {
                  _direct = v;
                  if (v) {
                    // 등록된 장소 이름이 남아 있으면 비우고 새로 입력하게 한다.
                    _placeId = '';
                    _placeName.clear();
                  }
                }),
              ),
            ],
          ),
          if (matching.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '프로필 탭에서 병원·미용실을 등록해 두면 여기에서 바로 고를 수 있어요.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (_direct) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _placeName,
              decoration: const InputDecoration(
                labelText: '장소 이름',
                border: OutlineInputBorder(),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('프로필 장소로도 저장'),
              subtitle: const Text('다음부터 선택 버튼으로 고를 수 있어요'),
              value: _saveAsPlace,
              onChanged: (v) => setState(() => _saveAsPlace = v ?? false),
            ),
          ],
          gap,
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '금액(원)',
              border: OutlineInputBorder(),
            ),
          ),
          gap,
          TextField(
            controller: _detail,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: isHospital
                  ? '증상·진단'
                  : (_type == '미용' ? '시술 내용(스타일, 길이 등)' : '내용'),
              border: const OutlineInputBorder(),
            ),
          ),
          if (isHospital) ...[
            gap,
            TextField(
              controller: _prescription,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '처방·처치',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          gap,
          TextField(
            controller: _memo,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '메모',
              border: OutlineInputBorder(),
            ),
          ),
          gap,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event_repeat, size: 18),
                  label: Text(
                    _nextDate.isEmpty ? '다음 예약일(선택)' : '다음 예약 $_nextDate',
                  ),
                  onPressed: () async {
                    final d = await _pickDate(_nextDate);
                    if (d != null) setState(() => _nextDate = d);
                  },
                ),
              ),
              if (_nextDate.isNotEmpty)
                IconButton(
                  onPressed: () => setState(() => _nextDate = ''),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          gap,
          if (!_photosLoaded) const LinearProgressIndicator(),
          _compare(),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < _photos.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _openPhoto(i),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(_photos[i].photoBase64),
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            color: Colors.black54,
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              _photos[i].label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: InkWell(
                            onTap: () => setState(
                              () => _photos = [..._photos]..removeAt(i),
                            ),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_photosLoaded)
                  InkWell(
                    onTap: _addPhotos,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined),
                          SizedBox(height: 4),
                          Text('사진 추가'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!widget.isNew && widget.onDelete != null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('이 기록 삭제'),
            ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

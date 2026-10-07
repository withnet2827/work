import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/attachment.dart';
import '../models/daily_log.dart';
import '../models/diary_entry.dart';
import 'attachment_viewer_screen.dart';
import 'daily_log_sections.dart';
import '../util/photo_compress.dart';

String todayString([DateTime? now]) {
  final n = now ?? DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

/// 일기 작성·수정. 저장/삭제는 호출한 쪽이 넘긴 함수로 처리하고, 성공하면 화면을 닫는다.
class DiaryEditScreen extends StatefulWidget {
  const DiaryEditScreen({
    super.key,
    required this.entry,
    required this.isNew,
    required this.onSave,
    this.onDelete,
  });
  final DiaryEntry entry;
  final bool isNew;
  final Future<void> Function(DiaryEntry) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<DiaryEditScreen> createState() => _DiaryEditScreenState();
}

class _DiaryEditScreenState extends State<DiaryEditScreen> {
  late final _body = TextEditingController(text: widget.entry.body);
  late String _date = widget.entry.date;
  late String _mood = widget.entry.mood;
  late List<String> _photos = List.of(widget.entry.photos);
  late List<WalkLog> _walks = List.of(widget.entry.walks);
  late List<FeedLog> _feeds = List.of(widget.entry.feeds);
  bool _busy = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_date) ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (d != null) setState(() => _date = todayString(d));
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
    if (source == null) return;
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
    final added = [for (final f in files) compressPhoto(await f.readAsBytes())];
    if (mounted && added.isNotEmpty) {
      setState(() => _photos = [..._photos, ...added]);
    }
  }

  Future<void> _save() async {
    if (_body.text.trim().isEmpty &&
        _photos.isEmpty &&
        _walks.isEmpty &&
        _feeds.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('내용이나 사진을 넣어 주세요.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onSave(
        widget.entry.copyWith(
          date: _date,
          body: _body.text.trim(),
          mood: _mood,
          photos: _photos,
          walks: _walks,
          feeds: _feeds,
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
        title: const Text('일기 삭제'),
        content: const Text('이 일기를 삭제할까요? 사진도 함께 삭제됩니다.'),
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

  void _openPhoto(int i) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttachmentViewerScreen(
          attachments: [
            for (var k = 0; k < _photos.length; k++)
              Attachment(id: '$k', photoBase64: _photos[k], label: '일기'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? '일기 쓰기' : '일기 수정'),
        actions: [
          if (!widget.isNew && widget.onDelete != null)
            IconButton(
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: '삭제',
            ),
          TextButton(onPressed: _busy ? null : _save, child: const Text('저장')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(_date),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final m in DiaryEntry.moods)
                ChoiceChip(
                  label: Text(m, style: const TextStyle(fontSize: 20)),
                  selected: _mood == m,
                  onSelected: (v) => setState(() => _mood = v ? m : ''),
                ),
            ],
          ),
          const SizedBox(height: 12),
          WalkSection(
            walks: _walks,
            onChanged: (v) => setState(() => _walks = v),
          ),
          FeedSection(
            feeds: _feeds,
            onChanged: (v) => setState(() => _feeds = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 6,
            maxLines: 14,
            decoration: const InputDecoration(
              hintText: '오늘 치오는 어땠나요?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
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
                              base64Decode(_photos[i]),
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
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
              label: const Text('이 일기 삭제'),
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

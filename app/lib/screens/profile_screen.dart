import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/attachment.dart';
import '../models/pet_profile.dart';
import '../models/place.dart';
import '../widgets_pet_avatar.dart';
import 'attachment_viewer_screen.dart';
import 'place_edit_screen.dart';
import '../util/photo_compress.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.onEdit,
    required this.onChanged,
  });
  final PetProfile profile;
  final VoidCallback onEdit;
  final ValueChanged<PetProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('성별', profile.gender),
      ('중성화', profile.neutered ? '완료' : '미확인/안 함'),
      ('생년월일', profile.birthDate),
      ('입양일', profile.adoptionDate),
      ('견종', profile.breed),
      ('동물등록번호', profile.registrationNo),
      ('알레르기', profile.allergies),
      ('특이사항', profile.notes),
    ];
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: PetAvatar(profile: profile, radius: 56)),
        const SizedBox(height: 8),
        Center(child: Text(profile.name, style: text.headlineSmall)),
        const SizedBox(height: 8),
        for (final (label, value) in rows)
          ListTile(
            title: Text(label, style: text.labelMedium),
            subtitle: Text(value.isEmpty ? '-' : value, style: text.bodyLarge),
          ),
        FilledButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit),
          label: const Text('프로필 수정'),
        ),
        const Divider(height: 40),
        Row(
          children: [
            Expanded(child: Text('병원·미용실 등 장소', style: text.titleMedium)),
            TextButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add),
              label: const Text('추가'),
            ),
          ],
        ),
        if (profile.places.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('등록된 장소가 없습니다. 추가 버튼으로 병원·미용실을 등록하세요.'),
          ),
        for (final p in profile.places)
          _PlaceCard(
            place: p,
            onEdit: () => _edit(context, p),
            onDelete: () => _delete(context, p),
            onChanged: (np) => onChanged(
              profile.copyWith(
                places: [
                  for (final e in profile.places) e.id == np.id ? np : e,
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _add(BuildContext context) async {
    final r = await Navigator.of(
      context,
    ).push<Place>(MaterialPageRoute(builder: (_) => const PlaceEditScreen()));
    if (r != null) onChanged(profile.copyWith(places: [...profile.places, r]));
  }

  Future<void> _edit(BuildContext context, Place p) async {
    final r = await Navigator.of(context).push<Place>(
      MaterialPageRoute(builder: (_) => PlaceEditScreen(initial: p)),
    );
    if (r != null) {
      onChanged(
        profile.copyWith(
          places: [for (final e in profile.places) e.id == p.id ? r : e],
        ),
      );
    }
  }

  Future<void> _delete(BuildContext context, Place p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${p.name} 삭제'),
        content: const Text('이 장소를 목록에서 삭제할까요?'),
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
    if (ok == true) {
      onChanged(
        profile.copyWith(
          places: profile.places.where((e) => e.id != p.id).toList(),
        ),
      );
    }
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.onEdit,
    required this.onDelete,
    required this.onChanged,
  });
  final Place place;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<Place> onChanged;

  Future<void> _addPhotos(BuildContext context) async {
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
    if (source == null || !context.mounted) return;
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
    if (files.isEmpty || !context.mounted) return;

    // 구분·날짜를 한 번에 지정
    final meta = await _askMeta(context, files.length);
    if (meta == null) return;
    final added = <Attachment>[];
    for (final f in files) {
      final bytes = await f.readAsBytes();
      added.add(
        Attachment(
          id: '${DateTime.now().microsecondsSinceEpoch}-${added.length}',
          photoBase64: compressPhoto(bytes),
          label: meta.$1,
          date: meta.$2,
        ),
      );
    }
    onChanged(place.copyWith(attachments: [...place.attachments, ...added]));
  }

  Future<(String, String)?> _askMeta(BuildContext context, int count) {
    var label = Attachment.labels.first;
    final now = DateTime.now();
    var date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return showDialog<(String, String)>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: Text('사진 $count장 정보'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: label,
                decoration: const InputDecoration(
                  labelText: '구분',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final l in Attachment.labels)
                    DropdownMenuItem(value: l, child: Text(l)),
                ],
                onChanged: (v) => label = v ?? label,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(date),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: c,
                    initialDate: DateTime.tryParse(date) ?? now,
                    firstDate: DateTime(2000),
                    lastDate: now,
                  );
                  if (d != null) {
                    setState(
                      () => date =
                          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, (label, date)),
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttachmentViewerScreen(
          attachments: place.attachments,
          initialIndex: index,
          onDelete: (a) => onChanged(
            place.copyWith(
              attachments: place.attachments
                  .where((e) => e.id != a.id)
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final q = place.mapQuery;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(place.category),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(place.name, style: text.titleMedium)),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: '수정',
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '삭제',
                ),
              ],
            ),
            if (place.phone.isNotEmpty) Text('전화  ${place.phone}'),
            if (place.address.isNotEmpty) Text('주소  ${place.address}'),
            if (place.memo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(place.memo, style: text.bodySmall),
            ],
            if (place.attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: place.attachments.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (c, i) {
                    final a = place.attachments[i];
                    return GestureDetector(
                      onTap: () => _openViewer(c, i),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(a.photoBase64),
                              width: 84,
                              height: 84,
                              fit: BoxFit.cover,
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
                                a.label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => _addPhotos(context),
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: Text(
                    place.attachments.isEmpty
                        ? '사진 첨부'
                        : '사진 ${place.attachments.length}장 · 추가',
                  ),
                ),
                if (place.phone.isNotEmpty)
                  TextButton.icon(
                    onPressed: () =>
                        _open(Uri(scheme: 'tel', path: place.phone)),
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('전화'),
                  ),
                if (q.isNotEmpty) ...[
                  TextButton.icon(
                    onPressed: () =>
                        _open(Uri.https('map.naver.com', '/p/search/$q')),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('네이버 지도'),
                  ),
                  TextButton.icon(
                    onPressed: () => _open(
                      Uri.https('www.google.com', '/maps/search/', {
                        'api': '1',
                        'query': q,
                      }),
                    ),
                    icon: const Icon(Icons.place_outlined, size: 18),
                    label: const Text('구글 지도'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

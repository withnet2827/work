import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pet_profile.dart';
import '../models/place.dart';
import '../widgets_pet_avatar.dart';
import 'place_edit_screen.dart';

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
        FilledButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit), label: const Text('프로필 수정')),
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
        for (final p in profile.places) _PlaceCard(place: p, onEdit: () => _edit(context, p), onDelete: () => _delete(context, p)),
      ],
    );
  }

  Future<void> _add(BuildContext context) async {
    final r = await Navigator.of(context).push<Place>(
      MaterialPageRoute(builder: (_) => const PlaceEditScreen()),
    );
    if (r != null) onChanged(profile.copyWith(places: [...profile.places, r]));
  }

  Future<void> _edit(BuildContext context, Place p) async {
    final r = await Navigator.of(context).push<Place>(
      MaterialPageRoute(builder: (_) => PlaceEditScreen(initial: p)),
    );
    if (r != null) {
      onChanged(profile.copyWith(places: [for (final e in profile.places) e.id == p.id ? r : e]));
    }
  }

  Future<void> _delete(BuildContext context, Place p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${p.name} 삭제'),
        content: const Text('이 장소를 목록에서 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true) {
      onChanged(profile.copyWith(places: profile.places.where((e) => e.id != p.id).toList()));
    }
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.onEdit, required this.onDelete});
  final Place place;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Future<void> _open(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

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
                Chip(label: Text(place.category), visualDensity: VisualDensity.compact),
                const SizedBox(width: 8),
                Expanded(child: Text(place.name, style: text.titleMedium)),
                IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), tooltip: '수정'),
                IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline), tooltip: '삭제'),
              ],
            ),
            if (place.phone.isNotEmpty) Text('전화  ${place.phone}'),
            if (place.address.isNotEmpty) Text('주소  ${place.address}'),
            if (place.memo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(place.memo, style: text.bodySmall),
            ],
            Wrap(
              spacing: 4,
              children: [
                if (place.phone.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _open(Uri(scheme: 'tel', path: place.phone)),
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('전화'),
                  ),
                if (q.isNotEmpty) ...[
                  TextButton.icon(
                    onPressed: () => _open(Uri.https('map.naver.com', '/p/search/$q')),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('네이버 지도'),
                  ),
                  TextButton.icon(
                    onPressed: () => _open(Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': q})),
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

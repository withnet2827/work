import 'package:flutter/material.dart';

import '../models/pet_profile.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.profile, required this.onEdit});
  final PetProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('이름', profile.name),
      ('성별', profile.gender),
      ('중성화', profile.neutered ? '완료' : '미확인/안 함'),
      ('생년월일', profile.birthDate),
      ('입양일', profile.adoptionDate),
      ('견종', profile.breed),
      ('동물등록번호', profile.registrationNo),
      ('알레르기', profile.allergies),
      ('특이사항', profile.notes),
      ('단골 병원', _join(profile.clinicName, profile.clinicPhone)),
      ('단골 미용실', _join(profile.groomerName, profile.groomerPhone)),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final (label, value) in rows)
          ListTile(
            title: Text(label, style: Theme.of(context).textTheme.labelMedium),
            subtitle: Text(value.isEmpty ? '-' : value,
                style: Theme.of(context).textTheme.bodyLarge),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit),
          label: const Text('프로필 수정'),
        ),
      ],
    );
  }

  static String _join(String a, String b) =>
      [a, b].where((e) => e.isNotEmpty).join(' · ');
}

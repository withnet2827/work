import 'dart:convert';

import 'package:flutter/material.dart';

import 'models/pet_profile.dart';

class PetAvatar extends StatelessWidget {
  const PetAvatar({super.key, required this.profile, this.radius = 44});
  final PetProfile profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (profile.photoBase64.isNotEmpty) {
      try {
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(base64Decode(profile.photoBase64)),
        );
      } catch (_) {
        // 손상된 사진 데이터는 기본 아이콘으로 대체
      }
    }
    return CircleAvatar(
      radius: radius,
      child: Icon(Icons.pets, size: radius),
    );
  }
}

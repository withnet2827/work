import 'package:shared_preferences/shared_preferences.dart';

import '../models/pet_profile.dart';

/// 프로필 저장소 인터페이스. 가족 공유 단계에서 Firestore 구현으로 교체한다.
abstract class ProfileStore {
  Future<PetProfile> load();
  Future<void> save(PetProfile profile);
}

class LocalProfileStore implements ProfileStore {
  static const _key = 'pet_profile_v1';

  @override
  Future<PetProfile> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_key);
    return s == null ? const PetProfile() : PetProfile.fromJson(s);
  }

  @override
  Future<void> save(PetProfile profile) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, profile.toJson());
  }
}

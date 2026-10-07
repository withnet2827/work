import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class Family {
  const Family({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.memberUids,
  });
  final String id;
  final String name;
  final String inviteCode;
  final List<String> memberUids;
}

/// 가족(공유 단위) 생성·참여. 데이터 구조:
///   families/{id}            : name, inviteCode, ownerUid, memberUids[]
///   invites/{code}           : familyId
class FamilyService {
  FamilyService([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  static const _alphabet =
      'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 헷갈리는 글자(0,O,1,I) 제외

  static String _newCode() {
    final r = Random.secure();
    return List.generate(
      6,
      (_) => _alphabet[r.nextInt(_alphabet.length)],
    ).join();
  }

  Family _from(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Family(
      id: d.id,
      name: m['name'] as String? ?? '',
      inviteCode: m['inviteCode'] as String? ?? '',
      memberUids: List<String>.from(m['memberUids'] as List? ?? const []),
    );
  }

  Future<Family?> findMine(String uid) async {
    final q = await _db
        .collection('families')
        .where('memberUids', arrayContains: uid)
        .limit(1)
        .get();
    return q.docs.isEmpty ? null : _from(q.docs.first);
  }

  Future<Family> create(String name, String uid) async {
    final fam = _db.collection('families').doc();
    for (var i = 0; i < 5; i++) {
      final code = _newCode();
      final invite = _db.collection('invites').doc(code);
      if ((await invite.get()).exists) continue;
      final batch = _db.batch();
      batch.set(fam, {
        'name': name,
        'inviteCode': code,
        'ownerUid': uid,
        'memberUids': [uid],
      });
      batch.set(invite, {'familyId': fam.id});
      await batch.commit();
      return _from(await fam.get());
    }
    throw StateError('초대 코드를 만들지 못했습니다. 다시 시도해 주세요.');
  }

  /// 초대 코드로 참여. 코드가 없으면 null.
  Future<Family?> join(String code, String uid) async {
    final inv = await _db
        .collection('invites')
        .doc(code.trim().toUpperCase())
        .get();
    if (!inv.exists) return null;
    final famRef = _db
        .collection('families')
        .doc(inv.data()!['familyId'] as String);
    await famRef.update({
      'memberUids': FieldValue.arrayUnion([uid]),
    });
    return _from(await famRef.get());
  }
}

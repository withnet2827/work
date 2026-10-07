import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/firestore_diary_store.dart';
import '../data/firestore_profile_store.dart';
import '../data/firestore_visit_store.dart';
import '../screens/home_shell.dart';
import 'family.dart';
import 'family_setup_screen.dart';
import 'login_screen.dart';

/// 로그인 → 가족 확인 → 홈 순서로 화면을 정한다.
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  final _service = FamilyService();
  Family? _family;
  String? _loadedFor; // _family를 조회한 uid
  Object? _error;

  Future<void> _loadFamily(String uid) async {
    try {
      final f = await _service.findMine(uid);
      if (mounted) {
        setState(() {
          _family = f;
          _loadedFor = uid;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user == null) {
          _family = null;
          _loadedFor = null;
          return const LoginScreen();
        }
        if (_error != null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '가족 정보를 불러오지 못했습니다.\n$_error\n\nFirestore 규칙과 설정을 확인해 주세요.',
                ),
              ),
            ),
          );
        }
        if (_loadedFor != user.uid) {
          _loadFamily(user.uid);
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (_family == null) {
          return FamilySetupScreen(
            uid: user.uid,
            service: _service,
            onDone: (f) => setState(() => _family = f),
            onSignOut: () => FirebaseAuth.instance.signOut(),
          );
        }
        final family = _family!;
        return HomeShell(
          key: ValueKey(family.id),
          store: FirestoreProfileStore(family.id),
          diaryStore: FirestoreDiaryStore(family.id),
          visitStore: FirestoreVisitStore(family.id),
          familyInfo: FamilyInfo(
            name: family.name,
            inviteCode: family.inviteCode,
            memberCount: family.memberUids.length,
            userLabel: user.displayName ?? user.email ?? '',
            onSignOut: () => FirebaseAuth.instance.signOut(),
          ),
        );
      },
    );
  }
}

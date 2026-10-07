import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth/app_gate.dart';
import 'data/profile_store.dart';
import 'firebase_config.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (FirebaseConfig.configured) {
    await Firebase.initializeApp(options: FirebaseConfig.options);
    runApp(const ChioApp());
  } else {
    // Firebase 미설정: 이 기기에만 저장하는 로컬 모드
    runApp(ChioApp(store: LocalProfileStore()));
  }
}

class ChioApp extends StatelessWidget {
  const ChioApp({super.key, this.store});

  /// null이면 로그인·가족 공유(Firebase) 모드.
  final ProfileStore? store;

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      colorSchemeSeed: const Color(0xFFE59A4F),
      useMaterial3: true,
    );
    return MaterialApp(
      title: '치오 데일리',
      debugShowCheckedModeBanner: false,
      theme: base,
      home: store == null ? const AppGate() : HomeShell(store: store!),
    );
  }
}

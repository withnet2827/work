import 'package:firebase_app_check/firebase_app_check.dart';
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
    if (FirebaseConfig.recaptchaSiteKey.isNotEmpty) {
      // 앱 체크: 우리 사이트에서 온 요청에만 AI 같은 서버 기능을 허용한다.
      // 실패해도 앱 자체는 쓸 수 있게 한다(AI 분석만 막힐 수 있음).
      try {
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider(FirebaseConfig.recaptchaSiteKey),
        );
      } catch (e) {
        debugPrint('앱 체크 활성화 실패: $e');
      }
    }
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

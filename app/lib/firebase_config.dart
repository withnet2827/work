import 'package:firebase_core/firebase_core.dart';

/// Firebase 웹 앱 설정. 값이 비어 있으면 앱은 '로컬 모드'(로그인 없음, 이 기기에만 저장)로 동작한다.
/// 웹 앱 설정값은 공개 식별자이며, 데이터 보호는 firestore.rules가 담당한다.
/// 값 입력 방법: docs/firebase-설정-가이드.md 참조.
class FirebaseConfig {
  static const apiKey = '';
  static const appId = '';
  static const messagingSenderId = '';
  static const projectId = '';
  static const authDomain = '';
  static const storageBucket = '';

  static bool get configured =>
      apiKey.isNotEmpty && appId.isNotEmpty && projectId.isNotEmpty;

  static FirebaseOptions get options => const FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: authDomain,
    storageBucket: storageBucket,
  );
}

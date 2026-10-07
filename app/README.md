# 치오 데일리 (앱)

반려견 치오의 프로필·일기·병원/미용 기록을 가족이 함께 쓰는 앱. 기획안: `../docs/치오-앱-기획안.md`

## 현재 상태 (Phase 1-A 시작)
- 하단 탭: 홈 / 일기(준비 중) / 병원·미용(준비 중) / 프로필
- 프로필 보기·수정 (동물등록번호, 알레르기, 단골 병원·미용실 등) — 현재는 기기 로컬 저장
- 다음 단계: Firebase 로그인·가족 공유 → 일기 → 병원·미용 기록

## Windows에서 실행
1. Flutter SDK 설치: https://docs.flutter.dev/install/windows (설치 후 `flutter doctor`)
2. Chrome으로 실행(가장 쉬움): `cd app` → `flutter run -d chrome`
3. 안드로이드 폰 실행: 폰에서 개발자 옵션·USB 디버깅 켠 뒤 USB 연결 → `flutter run`
4. 테스트: `flutter test`

## 주의
- Firebase 키 파일(`google-services.json` 등)은 저장소에 올리지 않는다 (`.gitignore` 참고).

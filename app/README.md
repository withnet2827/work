# 치오 데일리 (앱)

반려견 치오의 프로필·일기·병원/미용 기록을 가족이 함께 쓰는 앱. 기획안: `../docs/치오-앱-기획안.md`

## 현재 상태 (Phase 1-A 시작)
- 하단 탭: 홈 / 일기(준비 중) / 병원·미용(준비 중) / 프로필
- 프로필 보기·수정 (사진, 동물등록번호, 알레르기 등) — 현재는 기기 로컬 저장
- 장소 목록: 병원·미용실·약국·펫호텔·용품점·기타를 여러 개 등록, 주소·전화·메모, 전화 걸기, 네이버/구글 지도 열기
- 다음 단계: Firebase 로그인·가족 공유 → 일기 → 병원·미용 기록

## Windows에서 실행
1. Flutter SDK 설치: https://docs.flutter.dev/install/windows (설치 후 `flutter doctor`)
2. Chrome으로 실행(가장 쉬움): `cd app` → `flutter run -d chrome --web-port 8080`
   - **반드시 포트를 고정**하세요. 포트가 바뀌면 저장된 데이터(브라우저 저장소)가 분리되어 사라진 것처럼 보입니다.
   - 항상 같은 주소 `http://localhost:8080`에서 열어야 데이터가 유지됩니다.
3. 안드로이드 폰 실행: 폰에서 개발자 옵션·USB 디버깅 켠 뒤 USB 연결 → `flutter run`
4. 테스트: `flutter test`

## 주의
- Firebase 키 파일(`google-services.json` 등)은 저장소에 올리지 않는다 (`.gitignore` 참고).

// 파일 고르기: 웹에서는 브라우저 파일 선택창, 그 외 플랫폼은 미지원(예외).
export 'file_pick_stub.dart' if (dart.library.js_interop) 'file_pick_web.dart';

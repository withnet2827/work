// 파일 내려받기: 웹에서는 브라우저 다운로드, 그 외 플랫폼은 미지원(예외).
export 'file_download_stub.dart'
    if (dart.library.js_interop) 'file_download_web.dart';

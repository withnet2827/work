import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// 파일 선택창을 열어 텍스트 내용을 돌려준다. 취소하면 null.
Future<String?> pickTextFile({String accept = '.json,application/json'}) {
  final c = Completer<String?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept;
  input.onchange = ((web.Event _) {
    final f = input.files?.item(0);
    if (f == null) {
      if (!c.isCompleted) c.complete(null);
      return;
    }
    f
        .text()
        .toDart
        .then((s) {
          if (!c.isCompleted) c.complete(s.toDart);
        })
        .catchError((Object e) {
          if (!c.isCompleted) c.completeError(e);
        });
  }).toJS;
  input.addEventListener(
    'cancel',
    ((web.Event _) {
      if (!c.isCompleted) c.complete(null);
    }).toJS,
  );
  input.click();
  return c.future;
}

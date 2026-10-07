import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> downloadTextFile(
  String filename,
  String content, {
  String mime = 'text/plain',
}) async {
  final bytes = utf8.encode(content);
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: '$mime;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body!.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}

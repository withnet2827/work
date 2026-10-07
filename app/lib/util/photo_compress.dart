import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 저장소가 받는 base64 문자 수 한도(900000)보다 여유 있게 잡은 목표치.
const photoTargetChars = 700000;

/// 사진을 한도 안으로 자동 압축해 base64로 돌려준다.
/// 이미 작으면 그대로 두고, 크면 가로 크기와 화질을 단계적으로 낮춘다.
/// 해석할 수 없는 형식이면 원본을 그대로 돌려준다(저장소가 용량을 검사한다).
String compressPhoto(Uint8List bytes, {int targetChars = photoTargetChars}) {
  final original = base64Encode(bytes);
  if (original.length <= targetChars) return original;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return original;
  final oriented = img.bakeOrientation(decoded);
  const steps = [(1280, 75), (1024, 70), (800, 65), (640, 60), (480, 55)];
  var best = original;
  for (final (width, quality) in steps) {
    final resized = oriented.width > width
        ? img.copyResize(oriented, width: width)
        : oriented;
    final out = base64Encode(img.encodeJpg(resized, quality: quality));
    if (out.length < best.length) best = out;
    if (out.length <= targetChars) return out;
  }
  return best;
}

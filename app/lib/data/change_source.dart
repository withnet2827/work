import 'dart:async';

import 'package:flutter/foundation.dart';

/// 다른 가족이 바꾼 내용을 알려 주는 저장소(Firestore)가 구현한다.
/// 로컬 저장소는 구현하지 않는다(이 기기에서만 쓰이므로 알릴 일이 없다).
abstract interface class ChangeSource {
  /// 데이터가 바뀔 때마다 이벤트를 낸다(구독 시작 직후의 최초 상태는 제외).
  Stream<void> get changes;
}

/// 저장소의 변경을 구독하고, 짧은 시간에 몰린 이벤트를 모아 [onChange]를 한 번만 부른다.
class ChangeWatcher {
  ChangeWatcher(
    Object? store,
    this.onChange, {
    this.delay = const Duration(milliseconds: 600),
  }) {
    if (store is ChangeSource) {
      _sub = store.changes.listen(
        (_) {
          _timer?.cancel();
          _timer = Timer(delay, onChange);
        },
        onError: (Object e) => debugPrint('실시간 반영 오류: $e'),
      );
    }
  }

  final VoidCallback onChange;
  final Duration delay;
  StreamSubscription<void>? _sub;
  Timer? _timer;

  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
  }
}

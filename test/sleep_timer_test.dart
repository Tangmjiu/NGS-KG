// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/providers/mixins.dart';

class _SleepTimer extends ChangeNotifier with SleepTimerMixin {
  int expirations = 0;

  @override
  void onSleepTimerExpired() => expirations++;

  @override
  void dispose() {
    disposeSleepTimer();
    super.dispose();
  }
}

void main() {
  testWidgets('到期只回调一次，并安全清空剩余时间', (tester) async {
    final timer = _SleepTimer();
    addTearDown(timer.dispose);
    var notifications = 0;
    timer.addListener(() => notifications++);

    timer.setSleepTimer(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(timer.sleepTimerRemaining, const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(timer.sleepTimerRemaining, isNull);
    expect(timer.expirations, 1);
    expect(notifications, 3);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 5));
    expect(timer.expirations, 1);
    expect(notifications, 3);
  });

  testWidgets('取消或销毁后不再触发到期回调', (tester) async {
    final timer = _SleepTimer();
    timer.setSleepTimer(const Duration(seconds: 1));
    timer.cancelSleepTimer();
    await tester.pump(const Duration(seconds: 2));
    expect(timer.sleepTimerRemaining, isNull);
    expect(timer.expirations, 0);

    timer.setSleepTimer(const Duration(seconds: 1));
    timer.dispose();
    await tester.pump(const Duration(seconds: 2));
    expect(timer.expirations, 0);
    expect(tester.takeException(), isNull);
  });
}

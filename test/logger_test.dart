// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/utils/logger.dart';

void main() {
  test('内存日志按写入顺序保留最后 2000 条', () {
    runZoned(
      () {
        for (var i = 0; i < 2005; i++) {
          Log.d('buffer-test', 'entry-$i');
        }
      },
      zoneSpecification: ZoneSpecification(
        print: (_, __, ___, ____) {},
      ),
    );

    final entries = Log.entries;
    expect(entries, hasLength(2000));
    expect(entries.first.message, 'entry-5');
    expect(entries.last.message, 'entry-2004');
    expect(Log.onEntry.value, same(entries.last));
    expect(() => entries.clear(), throwsUnsupportedError);
  });
}

// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

// 歌词解析测试，直接跑真实实现（不再自造假解析器）：
//
// 1. LRC：lib/providers/player_provider.dart 的 `_loadEmbeddedLyrics` 对以
//    `[mm:ss` 开头的文本调用 `LyricController.loadLyric(text)`，这里就用同一个
//    `LyricController` + `loadLyric` 断言行数、文本、时间和翻译。
// 2. KRC：`_fetchOnlineLyrics` 用 `KrcLyricUtil.parseLyrics(bytes)` 解析 KRC 字节。
//    该路径依赖网络取字节且 `_buildLyricLines` 是私有方法，单测无法稳定走通，
//    因此改为直接测真实的 `KrcLyricUtil.parseLyrics`：用 KRC 真实容器格式
//    （'krc1' 头 + 16 字节循环异或 + zlib 压缩）构造样本，验证解压/解密/逐字解析。

import 'dart:convert';
import 'dart:io';

import 'package:flutter_lyric/core/lyric_controller.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ym_lyric/model/krc_lyric_model.dart';
import 'package:ym_lyric/utils/krc_lyric_util.dart';

/// 走 PlayerProvider 使用的真实 LRC 路径。
LyricModel loadRealLrc(String raw, {String? translation}) {
  final controller = LyricController();
  try {
    controller.loadLyric(raw, translationLyric: translation);
    final model = controller.lyricNotifier.value;
    expect(model, isNotNull, reason: 'loadLyric 后 lyricNotifier 应有模型');
    return model!;
  } finally {
    controller.dispose();
  }
}

// KrcLyricUtil 解密用的 16 字节密钥（与实现保持一致）。
const _krcKey = <int>[
  64, 71, 97, 119, 94, 50, 116, 71,
  81, 54, 49, 45, 206, 210, 110, 105,
];

/// 按 KRC 真实容器格式打包：'krc1' + (utf8 文本 → zlib 压缩 → 循环异或)。
List<int> encodeKrc(String content) {
  final compressed = ZLibEncoder().convert(utf8.encode(content));
  final encrypted = <int>[
    for (var i = 0; i < compressed.length; i++)
      compressed[i] ^ _krcKey[i % _krcKey.length],
  ];
  return <int>[...ascii.encode('krc1'), ...encrypted];
}

void main() {
  group('LRC 解析（flutter_lyric LyricController 真实实现）', () {
    const raw = '[ti:Test Song]\n'
        '[ar:Test Artist]\n'
        '[00:01.00]Hello\n'
        '[00:02.50]World\n';

    test('行数、文本、时间与标签', () {
      final model = loadRealLrc(raw);

      expect(model.lines.length, 2);
      expect(model.lines[0].text, 'Hello');
      expect(model.lines[0].start, const Duration(milliseconds: 1000));
      expect(model.lines[1].text, 'World');
      expect(model.lines[1].start, const Duration(milliseconds: 2500));
      // 标签不占歌词行
      expect(model.idTags['ti'], 'Test Song');
      expect(model.idTags['ar'], 'Test Artist');
    });

    test('毫秒位为 3 位时按毫秒解析', () {
      final model = loadRealLrc('[01:30.123]Test\n');

      expect(model.lines.length, 1);
      expect(model.lines[0].start, const Duration(milliseconds: 90123));
    });

    test('乱序时间戳按时间排序', () {
      final model = loadRealLrc(
        '[00:03.00]Third\n[00:01.00]First\n[00:02.00]Second\n',
      );

      expect(
        model.lines.map((line) => line.text).toList(),
        <String>['First', 'Second', 'Third'],
      );
    });

    test('一行多个时间戳展开为多行', () {
      final model = loadRealLrc('[00:05.00][00:07.50]Chorus\n');

      expect(model.lines.length, 2);
      expect(model.lines.map((line) => line.text).toSet(), <String>{'Chorus'});
      expect(model.lines[0].start, const Duration(milliseconds: 5000));
      expect(model.lines[1].start, const Duration(milliseconds: 7500));
    });

    test('translationLyric 按时间戳关联到对应行', () {
      final model = loadRealLrc(
        '[00:01.00]Hello\n[00:02.50]World\n',
        translation: '[00:01.00]你好\n[00:02.50]世界\n',
      );

      expect(model.lines[0].translation, '你好');
      expect(model.lines[1].translation, '世界');
    });

    test('无时间戳的纯文本不产生时间轴（由 Provider 走纯文本分支）', () {
      final model = loadRealLrc('just a line\nanother line\n');

      expect(model.lines, isEmpty);
    });

    test('只有时间戳的空文本行会被保留（真实解析行为）', () {
      final model = loadRealLrc('[00:01.00]\n[00:02.00]Text\n');

      expect(model.lines.length, 2);
      expect(model.lines[0].text, '');
      expect(model.lines[1].text, 'Text');
    });

    test('setProgress 驱动激活行（播放器高亮依赖此行为）', () {
      final controller = LyricController();
      addTearDown(controller.dispose);
      controller.loadLyric(raw);
      expect(controller.lyricNotifier.value, isNotNull);

      controller.setProgress(const Duration(seconds: 3));
      expect(controller.activeIndexNotifiter.value, 1);

      controller.setProgress(const Duration(milliseconds: 1000));
      expect(controller.activeIndexNotifiter.value, 0);
    });
  });

  group('KRC 解析（ym_lyric KrcLyricUtil 真实实现）', () {
    const krcContent = '[ti:Krc Title]\n'
        '[ar:Krc Artist]\n'
        '[0,1000]<0,500,0>He<500,500,0>llo\n'
        '[1000,800]<1000,800,0>World\n';

    test('解密解压后得到行时间、逐字文本与标签', () {
      final KrcLyricModel model = KrcLyricUtil.parseLyrics(encodeKrc(krcContent));

      expect(model.krcLyricList.length, 2);

      final first = model.krcLyricList[0];
      expect(first.startTime, 0);
      expect(first.duration, 1000);
      expect(first.getWordLine(), 'Hello');
      expect(first.line![0].startTime, 0);
      expect(first.line![1].word, 'llo');
      expect(first.line![1].startTime, 500);

      final second = model.krcLyricList[1];
      expect(second.startTime, 1000);
      expect(second.duration, 800);
      expect(second.getWordLine(), 'World');

      expect(model.lyricTag.ti, 'Krc Title');
      expect(model.lyricTag.ar, 'Krc Artist');
    });

    test('非 KRC 数据不抛异常，返回空列表（Provider 据此降级 LRC）', () {
      final KrcLyricModel model = KrcLyricUtil.parseLyrics(
        utf8.encode('[00:01.00]not a krc payload'),
      );

      expect(model.krcLyricList, isEmpty);
    });
  });
}

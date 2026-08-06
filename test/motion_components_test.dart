// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/widgets/digit_ticker.dart';
import 'package:ngskg_plus/widgets/marquee_text.dart';
import 'package:ngskg_plus/widgets/wave_slider.dart';
import 'package:ngskg_plus/widgets/wavy_progress_indicator.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 200,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('MarqueeText', () {
    testWidgets('短文本不滚动，渲染静态 Text', (tester) async {
      await tester.pumpWidget(_wrap(
        const MarqueeText(text: '短文本', startDelay: Duration.zero),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(Text), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MarqueeText),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
    });

    testWidgets('超宽文本启动滚动，位移随时间变化', (tester) async {
      await tester.pumpWidget(_wrap(
        const MarqueeText(
          text: '这是一段非常非常长的文本用来触发跑马灯滚动效果展示',
          speed: 30,
          startDelay: Duration.zero,
        ),
      ));
      // 让滚动跑一段时间
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final transform = tester.widget<Transform>(find.descendant(
        of: find.byType(MarqueeText),
        matching: find.byType(Transform),
      ));
      final firstDx = transform.transform.getTranslation().x;

      await tester.pump(const Duration(milliseconds: 500));
      final transform2 = tester.widget<Transform>(find.descendant(
        of: find.byType(MarqueeText),
        matching: find.byType(Transform),
      ));
      final secondDx = transform2.transform.getTranslation().x;

      // 文本左移（dx 为负且持续变小）
      expect(firstDx, lessThan(0));
      expect(secondDx, lessThan(firstDx));
    });

    testWidgets('disableScroll 时强制静态', (tester) async {
      await tester.pumpWidget(_wrap(
        const MarqueeText(
          text: '这是一段非常非常长的文本用来触发跑马灯滚动效果展示',
          disableScroll: true,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.descendant(
          of: find.byType(MarqueeText),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
    });
  });

  group('DigitTicker', () {
    testWidgets('显示当前值，变化后更新', (tester) async {
      await tester.pumpWidget(_wrap(const DigitTicker(value: 1)));
      expect(find.text('1'), findsOneWidget);

      await tester.pumpWidget(_wrap(const DigitTicker(value: 2)));
      await tester.pump(const Duration(milliseconds: 500)); // 完成翻滚动画
      expect(find.text('2'), findsOneWidget);
    });

    test('formatter 与时长格式化逻辑', () {
      expect(DurationTicker.format(const Duration(minutes: 1, seconds: 5)),
          '01:05');
      expect(DurationTicker.format(const Duration(hours: 2, minutes: 3)),
          '2:03:00');
    });
  });

  group('WaveSlider', () {
    testWidgets('渲染不崩溃，拖动触发 onChanged', (tester) async {
      double? captured;
      await tester.pumpWidget(_wrap(
        WaveSlider(
          value: 0.5,
          onChanged: (v) => captured = v,
        ),
      ));

      await tester.drag(find.byType(WaveSlider), const Offset(80, 0));
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured, greaterThan(0.5)); // 向右拖 → 值增大
    });

    testWidgets('WaveformProgress 只读不拦截手势', (tester) async {
      await tester.pumpWidget(_wrap(
        const WaveformProgress(value: 0.3),
      ));
      expect(find.byType(WaveSlider), findsOneWidget);
    });
  });

  group('WavyProgressIndicator', () {
    testWidgets('indeterminate 与 determinate 模式均正常渲染动画', (tester) async {
      await tester.pumpWidget(_wrap(
        const SizedBox(height: 30, child: WavyProgressIndicator()),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_wrap(
        const SizedBox(height: 30, child: WavyProgressIndicator(value: 0.6)),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  });
}

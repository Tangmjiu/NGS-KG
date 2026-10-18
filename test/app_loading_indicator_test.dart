// SPDX-License-Identifier: MIT
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/ui/components/app_loading_indicator.dart';
import 'package:ngskg_plus/ui/foundation/app_motion_theme.dart';

class _Harness {
  final enabled = ValueNotifier(true);
  final reduced = ValueNotifier(false);
  final double durationScale;

  _Harness({this.durationScale = 1});

  Widget get app => MaterialApp(
        home: Theme(
          data: ThemeData(extensions: [
            AppMotionTheme(durationScale: durationScale),
          ]),
          child: ValueListenableBuilder<bool>(
            valueListenable: reduced,
            child: ValueListenableBuilder<bool>(
              valueListenable: enabled,
              child: const Center(
                child: AppLoadingIndicator(semanticLabel: '正在加载推荐'),
              ),
              builder: (_, enabled, child) =>
                  TickerMode(enabled: enabled, child: child!),
            ),
            builder: (context, reduceMotion, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(disableAnimations: reduceMotion),
              child: child!,
            ),
          ),
        ),
      );

  void dispose() {
    enabled.dispose();
    reduced.dispose();
  }
}

Future<_Harness> _mount(WidgetTester tester,
    {bool reduced = false, double durationScale = 1}) async {
  final harness = _Harness(durationScale: durationScale);
  harness.reduced.value = reduced;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    harness.dispose();
  });
  await tester.pumpWidget(harness.app);
  await tester.pump();
  return harness;
}

Finder get _paint => find.descendant(
    of: find.byType(AppLoadingIndicator), matching: find.byType(CustomPaint));

Future<Uint8List> _pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.descendant(
    of: find.byType(AppLoadingIndicator),
    matching: find.byType(RepaintBoundary),
  ));
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return Uint8List.fromList(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }))!;
}

void _expectIdle(WidgetTester tester) {
  expect(tester.binding.transientCallbackCount, 0);
  expect(tester.binding.hasScheduledFrame, false);
}

void main() {
  testWidgets('加载图形具有语义和38/48尺寸，动画改变像素但不重建组件', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _mount(tester);
      expect(find.bySemanticsLabel('正在加载推荐'), findsOneWidget);
      expect(
          tester.getSize(find.byType(AppLoadingIndicator)), const Size(48, 48));
      expect(tester.getSize(_paint), const Size(38, 38));
      final paint = tester.widget<CustomPaint>(_paint);
      final first = await _pixels(tester);

      await tester.pump(const Duration(milliseconds: 250));

      expect(await _pixels(tester), isNot(orderedEquals(first)));
      expect(identical(tester.widget<CustomPaint>(_paint), paint), true);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('减少动效与隐藏页面停止Ticker，恢复后继续原相位', (tester) async {
    final harness = await _mount(tester, reduced: true);
    final first = await _pixels(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(await _pixels(tester), orderedEquals(first));
    _expectIdle(tester);

    harness.reduced.value = false;
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final moving = await _pixels(tester);
    expect(moving, isNot(orderedEquals(first)));

    harness.enabled.value = false;
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(await _pixels(tester), orderedEquals(moving));
    _expectIdle(tester);

    harness.enabled.value = true;
    await tester.pump();
    await tester.pump();
    expect(await _pixels(tester), orderedEquals(moving));
    await tester.pump(const Duration(milliseconds: 250));
    expect(await _pixels(tester), isNot(orderedEquals(moving)));
  });

  testWidgets('应用失活时冻结加载动画，回到前台恢复且不累计后台时间', (tester) async {
    await _mount(tester);
    addTearDown(() => tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    await tester.pump(const Duration(milliseconds: 250));
    final moving = await _pixels(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 2));
    expect(await _pixels(tester), orderedEquals(moving));
    _expectIdle(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(await _pixels(tester), orderedEquals(moving));
    await tester.pump(const Duration(milliseconds: 250));
    expect(await _pixels(tester), isNot(orderedEquals(moving)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('加载速度遵循主题durationScale', (tester) async {
    await _mount(tester);
    await tester.pump(const Duration(milliseconds: 300));
    final normal = await _pixels(tester);
    await tester.pumpWidget(const SizedBox.shrink());

    await _mount(tester, durationScale: 2);
    await tester.pump(const Duration(milliseconds: 300));
    expect(await _pixels(tester), isNot(orderedEquals(normal)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await _pixels(tester), orderedEquals(normal));
  });
}

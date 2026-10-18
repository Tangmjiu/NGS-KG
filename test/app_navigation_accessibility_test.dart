// SPDX-License-Identifier: MIT
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/ui/components/app_navigation.dart';
import 'package:ngskg_plus/ui/foundation/app_motion_scope.dart';

const _destinations = ['首页', '发现', '搜索', '资料库'];

Future<void> _mountNavigation(
  WidgetTester tester, {
  required bool rail,
  required double textScale,
  int initialIndex = 1,
  ValueChanged<int>? onSelected,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(rail ? 800 : 320, 760);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var selectedIndex = initialIndex;
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        padding: const EdgeInsets.only(bottom: 24),
        viewPadding: const EdgeInsets.only(bottom: 24),
      ),
      child: child!,
    ),
    home: StatefulBuilder(builder: (context, setState) {
      final navigation = AppNavigation(
        selectedIndex: selectedIndex,
        rail: rail,
        onSelected: (index) {
          onSelected?.call(index);
          setState(() => selectedIndex = index);
        },
      );
      return Scaffold(
        body: rail
            ? Row(children: [navigation, const Expanded(child: SizedBox())])
            : const SizedBox.expand(),
        bottomNavigationBar: rail ? null : navigation,
      );
    }),
  ));
  await tester.pumpAndSettle();
}

void _expectDestinations(WidgetTester tester, int selectedIndex) {
  final nodeIds = <int>{};
  for (var index = 0; index < _destinations.length; index++) {
    final label = _destinations[index];
    final node = tester.getSemantics(find.byTooltip(label));
    final data = node.getSemanticsData();
    // Material 会合并“第几个标签”等本地化文字；名称仍须可被读屏找到。
    expect(data.label, contains(label));
    expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
    expect(data.flagsCollection.isSelected,
        index == selectedIndex ? ui.Tristate.isTrue : ui.Tristate.isFalse);
    expect(node.rect.width, greaterThanOrEqualTo(48));
    expect(node.rect.height, greaterThanOrEqualTo(48));
    nodeIds.add(node.id);
  }
  expect(nodeIds, hasLength(_destinations.length));
}

void main() {
  for (final rail in [false, true]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('${rail ? '侧边栏' : '320宽导航栏'}在$textScale倍字体下有48像素目标、名称和选中语义',
          (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final selections = <int>[];
          await _mountNavigation(tester,
              rail: rail, textScale: textScale, onSelected: selections.add);
          _expectDestinations(tester, 1);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

          final search = tester.getSemantics(find.byTooltip('搜索'));
          search.owner!.performAction(search.id, ui.SemanticsAction.tap);
          await tester.pumpAndSettle();
          expect(selections, [2]);
          _expectDestinations(tester, 2);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }
  }

  testWidgets('导航栏支持Tab切换焦点、回车与空格激活以及Shift Tab返回', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final selections = <int>[];
      await _mountNavigation(tester,
          rail: false,
          textScale: 2,
          initialIndex: 0,
          onSelected: selections.add);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selections, [0]);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(selections, [0, 1]);
      _expectDestinations(tester, 1);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selections, [0, 1, 0]);
      _expectDestinations(tester, 0);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  for (final reduceMotion in [true, false]) {
    testWidgets(
        '系统${reduceMotion ? 'reduceMotion' : 'disableAnimations'}变化即时传入动效作用域',
        (tester) async {
      final dispatcher = tester.binding.platformDispatcher;
      final upstreamReduced = ValueNotifier(false);
      addTearDown(upstreamReduced.dispose);
      try {
        dispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures();
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => ValueListenableBuilder<bool>(
            valueListenable: upstreamReduced,
            builder: (context, reduced, _) => MediaQuery(
              // 固定上游值，以验证作用域能独立响应系统辅助功能通知。
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: AppMotionScope(child: child!),
            ),
          ),
          home: Builder(builder: (context) {
            return Text('减少动效：${MediaQuery.disableAnimationsOf(context)}');
          }),
        ));
        expect(find.text('减少动效：false'), findsOneWidget);

        dispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(
            reduceMotion: reduceMotion, disableAnimations: !reduceMotion);
        await tester.pumpAndSettle();
        expect(find.text('减少动效：true'), findsOneWidget);
        dispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures();
        await tester.pumpAndSettle();
        expect(find.text('减少动效：false'), findsOneWidget);

        upstreamReduced.value = true;
        await tester.pumpAndSettle();
        expect(find.text('减少动效：true'), findsOneWidget);
        dispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(
            reduceMotion: reduceMotion, disableAnimations: !reduceMotion);
        await tester.pumpAndSettle();
        dispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures();
        await tester.pumpAndSettle();
        expect(find.text('减少动效：true'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        dispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        await tester.pump();
        expect(tester.takeException(), isNull);
      } finally {
        dispatcher.clearAccessibilityFeaturesTestValue();
      }
    });
  }
}

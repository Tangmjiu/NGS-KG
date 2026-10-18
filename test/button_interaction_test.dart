// SPDX-License-Identifier: MIT
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/models/theme_pack.dart';
import 'package:ngskg_plus/theme/app_theme.dart';
import 'package:ngskg_plus/ui/components/app_primary_button.dart';

const _ordinaryKey = ValueKey('ordinary-button');
const _primaryKey = ValueKey('primary-button');

Widget _buttons({
  ThemePack pack = ngsNagisa,
  required VoidCallback onOrdinary,
  required VoidCallback onPrimary,
}) =>
    MaterialApp(
      theme: AppTheme.build(ngsNagisa.lightScheme!, pack),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                key: _ordinaryKey,
                onPressed: onOrdinary,
                child: const Text('普通操作'),
              ),
              const SizedBox(height: 24),
              AppPrimaryButton(
                key: _primaryKey,
                label: '主要操作',
                icon: Icons.play_arrow_rounded,
                onPressed: onPrimary,
              ),
            ],
          ),
        ),
      ),
    );

Finder _material(Finder button) =>
    find.descendant(of: button, matching: find.byType(Material)).first;

void _expectRadius(WidgetTester tester, Finder button, double radius) {
  expect(
    tester.widget<Material>(_material(button)).shape,
    isA<RoundedRectangleBorder>().having(
      (shape) => shape.borderRadius,
      '实际按钮材质的圆角',
      BorderRadius.circular(radius),
    ),
  );
}

void main() {
  testWidgets('按钮视觉分层，48dp触摸外沿可点击且按压改变实际形状', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var ordinaryCalls = 0;
      var primaryCalls = 0;
      await tester.pumpWidget(_buttons(
        onOrdinary: () => ordinaryCalls++,
        onPrimary: () => primaryCalls++,
      ));
      await tester.pumpAndSettle();
      final ordinary = find.byKey(_ordinaryKey);
      final primary = find.byKey(_primaryKey);

      expect(tester.getSize(_material(ordinary)).height, 40);
      expect(tester.getSize(_material(primary)).height, 56);
      for (final entry in [(ordinary, '普通操作'), (primary, '主要操作')]) {
        final rect = tester.getRect(entry.$1);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        final semanticFinder = find.bySemanticsLabel(entry.$2);
        expect(semanticFinder, findsOneWidget);
        final node = tester.getSemantics(semanticFinder);
        expect(node.rect.width, greaterThanOrEqualTo(48));
        expect(node.rect.height, greaterThanOrEqualTo(48));
        expect(
            node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);

        // 普通按钮这里位于40dp材质之外，仍应落入48dp触摸目标。
        await tester.tapAt(Offset(rect.center.dx, rect.top + 1));
        await tester.pumpAndSettle();
      }
      expect(ordinaryCalls, 1);
      expect(primaryCalls, 1);

      for (final entry in [(ordinary, 8.0), (primary, 12.0)]) {
        expect(tester.widget<Material>(_material(entry.$1)).shape,
            isA<StadiumBorder>());
        final gesture = await tester.startGesture(tester.getCenter(entry.$1));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        _expectRadius(tester, entry.$1, entry.$2);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.widget<Material>(_material(entry.$1)).shape,
            isA<StadiumBorder>());
      }
      expect(ordinaryCalls, 2);
      expect(primaryCalls, 2);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  for (final radius in [0.0, 17.0]) {
    testWidgets('旧主题序列化恢复后，显式${radius}dp圆角在真实按压及松开时保持', (tester) async {
      final legacy = ThemePack.fromJson({
        'id': 'legacy-buttons',
        'name': '旧按钮主题',
        'author': '测试',
        'version': 2,
        'shapes': {'md': radius},
      });
      final restored = ThemePack.fromJson(
          jsonDecode(jsonEncode(legacy.toJson())) as Map<String, dynamic>);
      var calls = 0;
      await tester.pumpWidget(_buttons(
        pack: restored,
        onOrdinary: () => calls++,
        onPrimary: () => calls++,
      ));
      await tester.pumpAndSettle();

      for (final button in [
        find.byKey(_ordinaryKey),
        find.byKey(_primaryKey)
      ]) {
        _expectRadius(tester, button, radius);
        final gesture = await tester.startGesture(tester.getCenter(button));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        _expectRadius(tester, button, radius);
        await gesture.up();
        await tester.pumpAndSettle();
        _expectRadius(tester, button, radius);
      }
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    });
  }
}

// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/theme/expressive_shape_config.dart';
import 'package:ngskg_plus/widgets/expressive_shapes.dart';

void main() {
  group('buildExpressiveShapePath', () {
    test('all shape kinds produce a non-empty bounded path', () {
      for (final kind in ExpressiveShapeKind.values) {
        final path = buildExpressiveShapePath(kind);
        expect(path.getBounds().isEmpty, isFalse,
            reason: '${kind.name} path should not be empty');

        final b = path.getBounds();
        // 单位路径（半径 1）边界应落在 [-1.2, 1.2] 内
        expect(b.left, greaterThanOrEqualTo(-1.2));
        expect(b.top, greaterThanOrEqualTo(-1.2));
        expect(b.right, lessThanOrEqualTo(1.2));
        expect(b.bottom, lessThanOrEqualTo(1.2));
      }
    });

    test('squircle is roughly square-ish and centered', () {
      final b =
          buildExpressiveShapePath(ExpressiveShapeKind.squircle).getBounds();
      // 超椭圆 n=3 应接近圆形边界（宽高比接近 1）
      expect(b.width, closeTo(b.height, 0.05));
      expect(b.center.dx, closeTo(0, 0.05));
      expect(b.center.dy, closeTo(0, 0.05));
    });

    test('different kinds produce different geometry', () {
      final circle =
          buildExpressiveShapePath(ExpressiveShapeKind.circle).getBounds();
      final cookie =
          buildExpressiveShapePath(ExpressiveShapeKind.cookie6).getBounds();
      final flower =
          buildExpressiveShapePath(ExpressiveShapeKind.flower6).getBounds();

      // 内凹形状的内切半径应比圆小（cookie/flower 边界矩形更扁更贴近中心）
      expect(cookie.height, lessThan(circle.height));
      expect(flower.height, lessThan(circle.height));
      expect(cookie.height, isNot(equals(flower.height)));
    });

    test('circle is a perfect unit circle', () {
      final b =
          buildExpressiveShapePath(ExpressiveShapeKind.circle).getBounds();
      expect(b.width, closeTo(2.0, 0.001));
      expect(b.height, closeTo(2.0, 0.001));
    });
  });

  group('expressive shape config', () {
    test('resolveExpressiveShapes 关闭时返回空表', () {
      expect(resolveExpressiveShapes(false, 'default'), isEmpty);
    });

    test('resolveExpressiveShapes 开启时覆盖全部目标', () {
      final shapes = resolveExpressiveShapes(true, 'modern');
      expect(shapes.length, ShapeTarget.values.length);
      for (final shape in shapes.values) {
        expect(shape, isA<ExpressiveShapeBorder>());
      }
    });

    test('presetById 回退到默认预设', () {
      expect(presetById(null).id, 'default');
      expect(presetById('不存在').id, 'default');
      expect(presetById('playful').label, '活泼');
    });

    test('ExpressiveShapeBorder 路径贴合目标矩形', () {
      const border = ExpressiveShapeBorder(ExpressiveShapeKind.gem);
      const rect = Rect.fromLTWH(10, 20, 100, 60);
      final path = border.getOuterPath(rect);
      final b = path.getBounds();
      // 形状应落在矩形内（非等比缩放适配）
      expect(b.left, greaterThanOrEqualTo(rect.left - 0.5));
      expect(b.top, greaterThanOrEqualTo(rect.top - 0.5));
      expect(b.right, lessThanOrEqualTo(rect.right + 0.5));
      expect(b.bottom, lessThanOrEqualTo(rect.bottom + 0.5));
      // 且大致填满矩形
      expect(b.width, closeTo(rect.width, 1.0));
      expect(b.height, closeTo(rect.height, 1.0));
    });
  });
}

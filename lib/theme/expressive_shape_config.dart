// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import '../widgets/expressive_shapes.dart';

/// 形状应用目标（保守子集，**排除播放器相关目标**：
/// 播放控件 / 迷你播放器 / 专辑封面不在预设体系内，避免影响播放 UI）
enum ShapeTarget {
  /// 卡片（Card / Dialog）
  cards,

  /// 浮动操作按钮 FAB
  fab,

  /// Chip
  chips,
}

extension ShapeTargetLabel on ShapeTarget {
  String get label => switch (this) {
        ShapeTarget.cards => '卡片',
        ShapeTarget.fab => 'FAB',
        ShapeTarget.chips => 'Chip',
      };
}

/// 形状预设（对标 Rhythm ExpressiveShapePresets）
///
/// 每套预设为各 [ShapeTarget] 指定一种 [ExpressiveShapeKind]。
class ExpressiveShapePreset {
  final String id;
  final String label;
  final String description;
  final Map<ShapeTarget, ExpressiveShapeKind> mapping;

  const ExpressiveShapePreset({
    required this.id,
    required this.label,
    required this.description,
    required this.mapping,
  });
}

/// 内置形状预设列表（与设置页横向 chips 对应）
const List<ExpressiveShapePreset> kShapePresets = [
  ExpressiveShapePreset(
    id: 'default',
    label: '默认',
    description: '柔和 Squircle，贴近 Material 3 标准',
    mapping: {
      ShapeTarget.cards: ExpressiveShapeKind.squircle,
      ShapeTarget.fab: ExpressiveShapeKind.circle,
      ShapeTarget.chips: ExpressiveShapeKind.circle,
    },
  ),
  ExpressiveShapePreset(
    id: 'modern',
    label: '现代',
    description: '八瓣 Cookie + 圆角菱形，利落有节奏',
    mapping: {
      ShapeTarget.cards: ExpressiveShapeKind.cookie8,
      ShapeTarget.fab: ExpressiveShapeKind.gem,
      ShapeTarget.chips: ExpressiveShapeKind.gem,
    },
  ),
  ExpressiveShapePreset(
    id: 'playful',
    label: '活泼',
    description: '六瓣花朵 + Cookie，俏皮灵动',
    mapping: {
      ShapeTarget.cards: ExpressiveShapeKind.flower6,
      ShapeTarget.fab: ExpressiveShapeKind.cookie6,
      ShapeTarget.chips: ExpressiveShapeKind.flower8,
    },
  ),
  ExpressiveShapePreset(
    id: 'organic',
    label: '有机',
    description: '花瓣与圆润曲线，自然柔和',
    mapping: {
      ShapeTarget.cards: ExpressiveShapeKind.flower8,
      ShapeTarget.fab: ExpressiveShapeKind.flower6,
      ShapeTarget.chips: ExpressiveShapeKind.circle,
    },
  ),
  ExpressiveShapePreset(
    id: 'geometric',
    label: '几何',
    description: 'Squircle + 菱形，克制而现代',
    mapping: {
      ShapeTarget.cards: ExpressiveShapeKind.squircle,
      ShapeTarget.fab: ExpressiveShapeKind.gem,
      ShapeTarget.chips: ExpressiveShapeKind.gem,
    },
  ),
  ExpressiveShapePreset(
    id: 'retro',
    label: '复古',
    description: 'Cookie 系列，怀旧播放器质感',
    mapping: {
      ShapeTarget.cards: ExpressiveShapeKind.cookie6,
      ShapeTarget.fab: ExpressiveShapeKind.cookie8,
      ShapeTarget.chips: ExpressiveShapeKind.cookie6,
    },
  ),
];

/// 按 id 查找预设
ExpressiveShapePreset presetById(String? id) {
  return kShapePresets.firstWhere(
    (p) => p.id == id,
    orElse: () => kShapePresets.first,
  );
}

/// 形状 → ShapeBorder
///
/// 将单位路径缩放到目标矩形（非等比，填满 bounds），供
/// Card/Dialog/FAB/Chip 等 theme 直接使用。
class ExpressiveShapeBorder extends OutlinedBorder {
  final ExpressiveShapeKind kind;

  const ExpressiveShapeBorder(this.kind, {super.side});

  @override
  OutlinedBorder copyWith({BorderSide? side}) =>
      ExpressiveShapeBorder(kind, side: side ?? this.side);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect, textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final unit = buildExpressiveShapePath(kind);
    final b = unit.getBounds();
    if (b.isEmpty || rect.isEmpty) return Path()..addRect(rect);

    final scaleX = rect.width / b.width;
    final scaleY = rect.height / b.height;
    // 列主序矩阵：对角为缩放，第 4 列为平移
    final matrix = Matrix4(
      scaleX,
      0,
      0,
      0,
      0,
      scaleY,
      0,
      0,
      0,
      0,
      1,
      0,
      rect.left - b.left * scaleX,
      rect.top - b.top * scaleY,
      0,
      1,
    );
    return unit.transform(matrix.storage);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final path = getOuterPath(rect, textDirection: textDirection);
    if (side.style != BorderStyle.none && side.width > 0) {
      canvas.drawPath(path, side.toPaint());
    }
  }

  @override
  ShapeBorder scale(double t) =>
      ExpressiveShapeBorder(kind, side: side.scale(t));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpressiveShapeBorder &&
          other.kind == kind &&
          other.side == side;

  @override
  int get hashCode => Object.hash(kind, side);
}

/// 解析当前生效的形状配置
///
/// [enabled] 关闭时返回空表（各目标回退到主题默认形状）。
Map<ShapeTarget, ExpressiveShapeBorder> resolveExpressiveShapes(
  bool enabled,
  String presetId,
) {
  if (!enabled) return const {};
  final preset = presetById(presetId);
  return preset.mapping.map(
    (target, kind) => MapEntry(target, ExpressiveShapeBorder(kind)),
  );
}

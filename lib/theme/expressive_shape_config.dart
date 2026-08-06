// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import '../widgets/expressive_shapes.dart';

/// 形状应用目标
///
/// 形状只用于**封面等固定比例元素**（歌单卡封面、轮播大卡等），
/// 避免全局替换卡片/按钮造成界面生硬杂乱。
/// （播放器相关目标同样刻意排除。）
enum ShapeTarget {
  /// 歌单/专辑等封面（正方形或横版大卡，固定比例）
  cover,
}

extension ShapeTargetLabel on ShapeTarget {
  String get label => switch (this) {
        ShapeTarget.cover => '封面',
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
///
/// 形状主要影响封面观感：Squircle 温和接近圆角方形、
/// Cookie 微凹有节奏、Flower 有机灵动。菱形（gem）不适合封面，不采用。
const List<ExpressiveShapePreset> kShapePresets = [
  ExpressiveShapePreset(
    id: 'default',
    label: '默认',
    description: '柔和 Squircle，贴近 Material 3 标准',
    mapping: {
      ShapeTarget.cover: ExpressiveShapeKind.squircle,
    },
  ),
  ExpressiveShapePreset(
    id: 'modern',
    label: '现代',
    description: 'Squircle + 圆角菱形点缀，利落有节奏',
    mapping: {
      ShapeTarget.cover: ExpressiveShapeKind.squircle,
    },
  ),
  ExpressiveShapePreset(
    id: 'playful',
    label: '活泼',
    description: '八瓣 Cookie 封面，俏皮灵动',
    mapping: {
      ShapeTarget.cover: ExpressiveShapeKind.cookie8,
    },
  ),
  ExpressiveShapePreset(
    id: 'organic',
    label: '有机',
    description: '八瓣花朵封面，自然柔和',
    mapping: {
      ShapeTarget.cover: ExpressiveShapeKind.flower8,
    },
  ),
  ExpressiveShapePreset(
    id: 'geometric',
    label: '几何',
    description: 'Squircle 封面，克制而现代',
    mapping: {
      ShapeTarget.cover: ExpressiveShapeKind.squircle,
    },
  ),
  ExpressiveShapePreset(
    id: 'retro',
    label: '复古',
    description: '六瓣 Cookie 封面，怀旧播放器质感',
    mapping: {
      ShapeTarget.cover: ExpressiveShapeKind.cookie6,
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

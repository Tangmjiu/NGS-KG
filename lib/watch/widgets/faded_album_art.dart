// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 圆形渐变淡出封面 — Cassette 风格：圆形裁剪 + 径向渐变边缘淡出

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 圆形渐变淡出封面。
///
/// 封面裁成圆形，边缘用径向渐变淡出（中心不透明 → 边缘透明），
/// 营造柔和的沉浸感，不使用高斯模糊（CPU 更省）。
class FadedAlbumArt extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final double alpha;

  /// 边缘淡出起始比例（0.2 = 从半径 20% 处开始淡出）
  final double fadeStart;

  const FadedAlbumArt({
    super.key,
    required this.imageUrl,
    required this.size,
    this.alpha = 0.7,
    this.fadeStart = 0.55,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final safeSize = size.clamp(1.0, double.infinity);

    final placeholder = Container(
      width: safeSize,
      height: safeSize,
      color: cs.surfaceContainerHigh,
      child: Icon(
        Icons.music_note_rounded,
        size: safeSize * 0.35,
        color: cs.onSurface.withValues(alpha: 0.2),
      ),
    );

    final hasUrl = imageUrl != null && imageUrl!.isNotEmpty;
    Widget image = hasUrl
        ? CachedNetworkImage(
            imageUrl: imageUrl!,
            width: safeSize,
            height: safeSize,
            fit: BoxFit.cover,
            memCacheWidth: (safeSize * 2).round(),
            placeholder: (_, __) => placeholder,
            errorWidget: (_, __, ___) => placeholder,
          )
        : placeholder;

    // 径向渐变淡出：中心不透明 → 边缘透明
    return SizedBox(
      width: safeSize,
      height: safeSize,
      child: CustomPaint(
        painter: _RadialFadePainter(fadeStart: fadeStart),
        child: ClipOval(
          child: Opacity(opacity: alpha, child: image),
        ),
      ),
    );
  }
}

/// 径向渐变淡出画笔：在圆形边缘绘制从黑到透明的遮罩。
class _RadialFadePainter extends CustomPainter {
  final double fadeStart;

  const _RadialFadePainter({required this.fadeStart});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        colors: [
          Colors.transparent,
          Colors.transparent,
          Colors.black,
        ],
        stops: [0.0, fadeStart, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RadialFadePainter old) => old.fadeStart != fadeStart;
}

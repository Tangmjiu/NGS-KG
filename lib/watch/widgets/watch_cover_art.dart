// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 手表专辑封面 — 圆屏圆形 / 方屏圆角矩形，自带占位与错误态

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../utils/watch_layout.dart';

/// 专辑封面。圆屏裁成圆形，方屏裁成圆角矩形。
class WatchCoverArt extends StatelessWidget {
  final String? imageUrl;
  final double size;

  /// 强制形状；null 时跟随屏幕形状
  final bool? round;

  const WatchCoverArt({
    super.key,
    required this.imageUrl,
    required this.size,
    this.round,
  });

  @override
  Widget build(BuildContext context) {
    // 安全下限：防止首帧 MediaQuery 尺寸未就绪时产生负值
    final s = size.clamp(1.0, double.infinity);
    final isRound = round ?? WatchLayout.of(context).isRound;
    final colorScheme = Theme.of(context).colorScheme;

    final placeholder = Container(
      width: s,
      height: s,
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.music_note_rounded,
        size: s * 0.4,
        color: colorScheme.onSurface.withValues(alpha: 0.3),
      ),
    );

    final hasUrl = imageUrl != null && imageUrl!.isNotEmpty;
    final child = hasUrl
        ? CachedNetworkImage(
            imageUrl: imageUrl!,
            width: s,
            height: s,
            fit: BoxFit.cover,
            memCacheWidth: (s * 2).round(),
            placeholder: (_, __) => placeholder,
            errorWidget: (_, __, ___) => placeholder,
          )
        : placeholder;

    return isRound
        ? ClipOval(child: SizedBox(width: s, height: s, child: child))
        : ClipRRect(
            borderRadius: BorderRadius.circular(s * 0.12),
            child: SizedBox(width: s, height: s, child: child),
          );
  }
}

// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../theme/theme_assets.dart';
import 'app_components.dart';

enum AppEmptyStateKind { content, collection, error }

/// 保留旧主题的空状态插画；无插画时沿用统一图标样式。
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final AppEmptyStateKind? kind;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.kind,
  });

  // 兼容已有页面的错误、歌单和收藏图标；特殊场景可显式指定 kind。
  AppEmptyStateKind get _kind =>
      kind ??
      switch (icon) {
        Icons.cloud_off_rounded => AppEmptyStateKind.error,
        Icons.queue_music_rounded ||
        Icons.favorite_border_rounded =>
          AppEmptyStateKind.collection,
        _ => AppEmptyStateKind.content,
      };

  @override
  Widget build(BuildContext context) {
    // 即使新旧主题的配色相同，也在资源改变时更新现有页面。
    final illustration =
        context.select<ThemeProvider?, String>((_) => switch (_kind) {
              AppEmptyStateKind.content => ThemeAssets.emptyContent,
              AppEmptyStateKind.collection => ThemeAssets.emptyPlaylist,
              AppEmptyStateKind.error => ThemeAssets.loadFailed,
            });
    return EmptyStateContent(
      icon: icon,
      title: title,
      message: message,
      action: action,
      illustration: illustration.isEmpty
          ? null
          : ThemeImage(assetPath: illustration, width: 160, height: 160),
    );
  }
}

// SPDX-License-Identifier: MIT
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme_tokens.dart';

/// 歌单、专辑与歌手详情共用的封面头，随内容宽度和字号自然展开。
class CollectionHeader extends StatelessWidget {
  final String title;
  final String kind;
  final String? subtitle;
  final String? coverUrl;
  final IconData fallbackIcon;
  final String? description;
  final List<Widget> actions;

  const CollectionHeader({
    super.key,
    required this.title,
    required this.kind,
    this.subtitle,
    this.coverUrl,
    this.fallbackIcon = Icons.album_rounded,
    this.description,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          tokens.pagePadding, 12, tokens.pagePadding, tokens.sectionSpacing),
      child: LayoutBuilder(builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 620 &&
            MediaQuery.textScalerOf(context).scale(16) <= 24;
        final extent = horizontal
            ? 200.0
            : (constraints.maxWidth * 0.58).clamp(136.0, 220.0);
        final cover = SizedBox.square(
          dimension: extent.clamp(0, constraints.maxWidth),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tokens.cardRadius),
            child: ColoredBox(
              color: theme.colorScheme.primaryContainer,
              child: coverUrl == null || coverUrl!.isEmpty
                  ? _placeholder(context)
                  : CachedNetworkImage(
                      imageUrl: coverUrl!.replaceAll('{size}', '480'),
                      fit: BoxFit.cover,
                      memCacheWidth: 480,
                      errorWidget: (_, __, ___) => _placeholder(context),
                      placeholder: (_, __) => _placeholder(context),
                    ),
            ),
          ),
        );
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(kind,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 8),
            Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.displaySmall)),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(subtitle!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            if (description != null && description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(description!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(spacing: 12, runSpacing: 12, children: actions),
            ],
          ],
        );
        if (horizontal) {
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            cover,
            SizedBox(width: tokens.sectionSpacing),
            Expanded(child: content),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          cover,
          const SizedBox(height: 24),
          content,
        ]);
      }),
    );
  }

  Widget _placeholder(BuildContext context) => Center(
          child: Icon(
        fallbackIcon,
        size: 64,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ));
}

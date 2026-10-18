// SPDX-License-Identifier: MIT
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_theme_tokens.dart';

class DiscoverMediaItem {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final IconData icon;
  final VoidCallback? onTap;

  const DiscoverMediaItem({
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.icon = Icons.music_note_rounded,
    this.onTap,
  });
}

/// 封面卡片统一按可用宽度排版，长列表只构建可见项。
class DiscoverMediaRail extends StatelessWidget {
  final List<DiscoverMediaItem> items;
  final bool compact;

  const DiscoverMediaRail({
    super.key,
    required this.items,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final textScale = MediaQuery.textScalerOf(context);
    final surfaces = [
      cs.secondaryContainer,
      cs.primaryContainer,
      cs.tertiaryContainer,
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final width = compact
          ? (constraints.maxWidth * 0.37).clamp(130.0, 164.0)
          : (constraints.maxWidth * 0.44).clamp(152.0, 196.0);
      final textHeight = textScale.scale(tt.titleMedium?.fontSize ?? 16) *
              (tt.titleMedium?.height ?? 1.5) *
              2 +
          textScale.scale(tt.bodySmall?.fontSize ?? 12) *
              (tt.bodySmall?.height ?? 1.4) +
          30;
      return SizedBox(
        height: width + textHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: tokens.pagePadding),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            final surface = surfaces[index % surfaces.length];
            return SizedBox(
              width: width,
              child: Material(
                color: surface,
                borderRadius: BorderRadius.circular(tokens.cardRadius),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: item.onTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: width,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            DiscoverArtwork(
                              url: item.imageUrl,
                              size: width,
                              radius: 0,
                              icon: item.icon,
                            ),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      surface.withValues(alpha: 0),
                                      surface,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (item.subtitle?.isNotEmpty ?? false) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

class DiscoverArtwork extends StatelessWidget {
  final String? url;
  final double size;
  final double radius;
  final IconData icon;

  const DiscoverArtwork({
    super.key,
    required this.url,
    required this.size,
    this.radius = 16,
    this.icon = Icons.music_note_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final source = url?.replaceAll('{size}', '480');
    final placeholder = ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(icon, color: cs.onSurfaceVariant, size: size * 0.38),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: source == null || source.isEmpty
            ? placeholder
            : CachedNetworkImage(
                imageUrl: source,
                fit: BoxFit.cover,
                // 保留原始比例，按显示宽度限制解码。
                memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                    .ceil()
                    .clamp(1, 640),
                placeholder: (_, __) => placeholder,
                errorWidget: (_, __, ___) => placeholder,
              ),
      ),
    );
  }
}

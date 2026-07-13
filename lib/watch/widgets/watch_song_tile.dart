// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 圆屏歌单列表项 — 大触控区域，适配圆形屏幕

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/song.dart' show Song;
import '../utils/watch_motion.dart';

class WatchSongTile extends StatelessWidget {
  final String title;
  final String? artist;
  final String? subtitle;
  final bool isPlaying;
  final VoidCallback? onTap;
  final Widget? trailing;

  const WatchSongTile({
    super.key,
    required this.title,
    this.artist,
    this.subtitle,
    this.isPlaying = false,
    this.onTap,
    this.trailing,
  });

  factory WatchSongTile.fromSong({
    required Song song,
    bool isPlaying = false,
    VoidCallback? onTap,
  }) {
    return WatchSongTile(
      title: song.name,
      artist: song.artistDisplay,
      subtitle: song.albumName,
      isPlaying: isPlaying,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: InkWell(
        onTap: () {
          WatchMotion.tap();
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: WatchMotion.durShort4,
          curve: WatchMotion.curveStandard,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isPlaying
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: trailing!,
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: WatchMotion.durShort3,
                      curve: WatchMotion.curveStandard,
                      style: theme.textTheme.bodyLarge!.copyWith(
                        fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                      ),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (artist != null && artist!.isNotEmpty)
                      Text(
                        artist!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: WatchMotion.durShort4,
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: isPlaying
                    ? Padding(
                        key: const ValueKey('playing'),
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.play_arrow,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('idle')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

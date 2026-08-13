// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 手表歌曲列表项 — M3E 胶囊条目，适配固定行高列表

import 'package:flutter/material.dart';

import '../../models/song.dart' show Song;
import '../theme/watch_theme.dart';
import '../utils/watch_motion.dart';

/// 歌曲条目。设计高度 ≤ 52，配合 [WatchScrollList] 的 itemExtent 使用。
class WatchSongTile extends StatefulWidget {
  final String title;
  final String? artist;
  final String? subtitle;
  final bool isPlaying;
  final VoidCallback? onTap;

  /// 前置插槽（序号、图标等）
  final Widget? leading;

  /// 后置插槽（操作按钮等）
  final Widget? trailing;

  const WatchSongTile({
    super.key,
    required this.title,
    this.artist,
    this.subtitle,
    this.isPlaying = false,
    this.onTap,
    this.leading,
    this.trailing,
  });

  factory WatchSongTile.fromSong({
    required Song song,
    bool isPlaying = false,
    VoidCallback? onTap,
    Widget? leading,
    Widget? trailing,
  }) {
    return WatchSongTile(
      title: song.name,
      artist: song.artistDisplay,
      subtitle: song.albumName,
      isPlaying: isPlaying,
      onTap: onTap,
      leading: leading,
      trailing: trailing,
    );
  }

  @override
  State<WatchSongTile> createState() => _WatchSongTileState();
}

class _WatchSongTileState extends State<WatchSongTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final subtitleText = (widget.artist != null && widget.artist!.isNotEmpty)
        ? widget.artist!
        : (widget.subtitle != null && widget.subtitle!.isNotEmpty)
            ? widget.subtitle!
            : null;

    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: WatchMotion.durShort2,
      curve: WatchMotion.curveEmphasized,
      child: Material(
        color: widget.isPlaying
            ? colorScheme.primaryContainer.withValues(alpha: 0.35)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(WatchShapeTokens.full),
        child: InkWell(
          onTap: widget.onTap == null
              ? null
              : () {
                  WatchMotion.tap();
                  widget.onTap!();
                },
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(WatchShapeTokens.full),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: widget.isPlaying
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: widget.isPlaying
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitleText != null)
                        Text(
                          subtitleText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: widget.isPlaying
                                ? colorScheme.primary.withValues(alpha: 0.7)
                                : colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (widget.isPlaying && widget.trailing == null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 4),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

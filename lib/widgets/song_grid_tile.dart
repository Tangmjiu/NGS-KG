// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../theme/theme_assets.dart';
import '../utils/theme.dart';
import 'playing_indicator.dart';
import 'song_tile.dart' show showSongContextMenu;

/// ✅ 新增适配代码：平板网格歌曲卡片（封面墙）
///
/// 与 [SongTile] 行为对齐：点击播放、长按/更多按钮弹出同一套上下文菜单；
/// 当前播放歌曲高亮并显示播放指示器。仅用于平板网格布局，手机端仍走 SongTile。
class SongGridTile extends StatelessWidget {
  final Song song;
  final void Function(Song song)? onTap;

  /// 多选模式（歌单/专辑详情）：封面右上角显示选择角标
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onSelectionToggle;

  /// 排行榜排名角标（左上角，非 null 时显示）
  final int? rank;

  /// 追加到长按上下文菜单末尾的自定义菜单项（如"从歌单移除"）
  final List<Widget>? contextMenuExtras;

  const SongGridTile({
    super.key,
    required this.song,
    this.onTap,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectionToggle,
    this.rank,
    this.contextMenuExtras,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // 精确选择：只订阅当前歌曲 ID 和播放状态，避免进度变化导致整卡 rebuild
    final playbackState = context
        .select<PlayerProvider, ({bool isCurrent, bool isPlaying})>(
      (p) => (
        isCurrent: p.currentSong?.id == song.id,
        isPlaying: p.currentSong?.id == song.id && p.isPlaying,
      ),
    );
    final isCurrent = playbackState.isCurrent;
    final isPlaying = playbackState.isPlaying;

    return Semantics(
      button: true,
      child: M3PressScale(
        scaleDown: 0.95,
        child: InkWell(
          borderRadius: AppShape.md,
          onTap: selectionMode
              ? onSelectionToggle
              : () => onTap?.call(song),
          // ✅ 多选模式下禁用长按菜单（避免与多选交互冲突）
          onLongPress: selectionMode
              ? null
              : () => showSongContextMenu(context, song,
                  extraItems: contextMenuExtras),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面（正方形，自适应列宽）
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: AppShape.md,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      song.thumbnailCoverUrl != null
                          ? CachedNetworkImage(
                              imageUrl: song.thumbnailCoverUrl!,
                              fit: BoxFit.cover,
                              // 限制解码尺寸（网格卡片最大 180dp × 2x ≈ 360px）
                              memCacheWidth: 360,
                              memCacheHeight: 360,
                              placeholder: (_, __) => _placeholder(cs),
                              errorWidget: (_, __, ___) => _placeholder(cs),
                            )
                          : _placeholder(cs),
                      // 当前播放遮罩 + 指示器
                      if (!selectionMode && isCurrent)
                        Container(
                          color: Colors.black.withValues(alpha: 0.4),
                          child: Center(
                            child: isPlaying
                                ? const PlayingIndicator(
                                    size: 32, color: Colors.white)
                                : const Icon(Icons.pause_rounded,
                                    color: Colors.white, size: 32),
                          ),
                        ),
                      // ✅ 排行榜排名角标（左上角）
                      if (rank != null)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: AppShape.sm,
                            ),
                            child: Text(
                              '$rank',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: rank! <= 3
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: rank! <= 3
                                    ? Colors.amberAccent
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      // ✅ 多选角标（右上角）
                      if (selectionMode)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: selected
                                  ? cs.primary
                                  : Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              selected
                                  ? Icons.check_rounded
                                  : Icons.circle_outlined,
                              size: 22,
                              color: selected ? cs.onPrimary : Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 歌名 + 歌手
              Text(
                song.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyMedium?.copyWith(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent ? cs.primary : cs.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                song.artistDisplay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerHighest,
      child: Center(child: albumPlaceholderWidget(size: 48)),
    );
  }
}

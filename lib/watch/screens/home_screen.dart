// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 手表主屏幕 — 圆屏适配首页，含问候语、当前播放与快速操作入口

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wear_plus/wear_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/player_provider.dart';
import '../utils/watch_motion.dart';
import '../widgets/watch_song_tile.dart';
import '../widgets/round_safe_area.dart';
import 'player_screen.dart';
import 'search_screen.dart';
import 'playlist_list_screen.dart';
import 'local_music_screen.dart';
import 'fm_screen.dart';
import 'settings_screen.dart';
import 'queue_screen.dart';
import 'liked_songs_screen.dart';

/// 手表版主屏幕 — 圆屏适配的首页（问候 + 当前播放 + 快速操作入口）
class WatchHomeScreen extends StatelessWidget {
  const WatchHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RoundSafeArea(
      child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 12,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. 问候标题 ──
            Text(
              'NGS-KG+ Watch',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            // ── 登录用户信息 ──
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (!auth.isLoggedIn || auth.user == null) {
                  return const SizedBox.shrink();
                }
                final user = auth.user!;
                final isVip = user.isVipActive ||
                    (user.vipType != null && user.vipType! > 0);
                return Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Row(
                    children: [
                      // 头像
                      ClipOval(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: (user.avatarUrl != null &&
                                  user.avatarUrl!.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: user.avatarUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: theme
                                        .colorScheme.surfaceContainerHighest,
                                  ),
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.person,
                                    size: 18,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  size: 18,
                                  color: theme.colorScheme.onSurface,
                                ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 昵称
                      Flexible(
                        child: Text(
                          user.nickname ?? '用户',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVip) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.workspace_premium,
                          size: 14,
                          color: Colors.amber,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            // ── 2. 当前播放（有歌曲时才显示） ──
            Consumer<PlayerProvider>(
              builder: (context, player, _) {
                final song = player.currentSong;
                if (song == null) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      WatchMotion.tap();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WatchPlayerScreen(),
                        ),
                      );
                    },
                    child: WatchSongTile.fromSong(
                      song: song,
                      isPlaying: player.isPlaying,
                    ).animate(key: ValueKey(song.id)).fadeIn(
                          duration: WatchMotion.durMedium2,
                          curve: WatchMotion.curveDecelerate,
                        ).slideY(
                          begin: 0.15,
                          duration: WatchMotion.durMedium2,
                          curve: WatchMotion.curveDecelerate,
                        ),
                  ),
                );
              },
            ),

              // ── 3. 快速操作区标题 ──
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '快捷操作',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // ── 4. 快速操作入口（2×3 网格） ──
            const _QuickActionGrid(),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 快速操作按钮网格
// ══════════════════════════════════════════════════════════════════════════════

/// 快速操作数据模型
class _ActionItem {
  final String label;
  final IconData icon;
  final WidgetBuilder? screenBuilder;

  const _ActionItem(this.label, this.icon, this.screenBuilder);
}

/// 2×3 快速操作按钮网格，适配圆屏
class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      children: [
        _QuickActionButton(
          item: const _ActionItem('搜索', Icons.search, null),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WatchSearchScreen()),
          ),
        ),
        _QuickActionButton(
          item: const _ActionItem('歌单', Icons.queue_music, null),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WatchPlaylistListScreen(),
            ),
          ),
        ),
        _QuickActionButton(
          item: const _ActionItem('队列', Icons.playlist_play, null),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WatchQueueScreen()),
          ),
        ),
        _QuickActionButton(
          item: const _ActionItem('电台', Icons.radio, null),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WatchFmScreen()),
          ),
        ),
        _QuickActionButton(
          item: const _ActionItem('设置', Icons.settings, null),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WatchSettingsScreen()),
          ),
        ),
        _QuickActionButton(
          item: const _ActionItem('本地', Icons.folder_open, null),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WatchLocalMusicScreen(),
            ),
          ),
        ),
        _QuickActionButton(
          item: const _ActionItem('收藏', Icons.favorite_outline_rounded, null),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WatchLikedSongsScreen(),
            ),
          ),
        ),
      ],
    );
  }

}

/// 单个圆形快速操作按钮 + 标签
class _QuickActionButton extends StatefulWidget {
  final _ActionItem item;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.item,
    required this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _pressed = false;

  void _handleTapDown(TapDownDetails _) => setState(() => _pressed = true);
  void _handleTapUp(TapUpDetails _) => setState(() => _pressed = false);
  void _handleTapCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isRound = WatchShape.of(context) == WearShape.round;

    return SizedBox(
      width: isRound ? 80 : 88,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            onTap: () {
              WatchMotion.tap();
              widget.onTap();
            },
            child: AnimatedScale(
              scale: _pressed ? 0.88 : 1.0,
              duration: WatchMotion.durShort2,
              curve: WatchMotion.curveEmphasized,
              child: Material(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  child: Icon(
                    widget.item.icon,
                    size: 26,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.item.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

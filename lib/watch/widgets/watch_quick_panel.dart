// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 底部快捷面板 — 底缘上滑调出的半圆形高频操作区

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/liked_songs_provider.dart';
import '../../providers/player_provider.dart';
import '../../utils/login_required_dialog.dart';
import '../screens/login_screen.dart';
import '../utils/watch_layout.dart';
import '../utils/watch_motion.dart';

/// 从屏幕底缘上滑调出的半圆快捷面板。
///
/// 高频操作：上一首 / 播放暂停 / 下一首 / 收藏 / 播放模式。
/// 所有操作均可点击完成；点击面板外或下滑关闭。
class WatchQuickPanel extends StatelessWidget {
  final VoidCallback onClose;

  const WatchQuickPanel({super.key, required this.onClose});

  /// 以底部弹出层方式展示。
  static Future<void> show(BuildContext context) {
    WatchMotion.heavy();
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭快捷面板',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: WatchMotion.durMedium2,
      pageBuilder: (context, _, __) =>
          WatchQuickPanel(onClose: () => Navigator.of(context).pop()),
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: WatchMotion.curveDecelerate,
        );
        return SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
              .animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    final d = layout.diameter;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onClose,
      onVerticalDragUpdate: (d) {
        if (d.delta.dy > 8) onClose();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {}, // 拦截：点击面板本身不关闭
            child: Container(
              // 圆屏底部是窄弦，宽度收窄；方屏全宽
              width: layout.isRound ? d * 0.88 : double.infinity,
              // 半圆形观感：高度约为宽的一半，顶部大圆角
              height: d * 0.56,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(d * 0.48),
                ),
                border: Border(
                  top: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // 抓手
                  Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Spacer(),
                  Consumer<PlayerProvider>(
                    builder: (context, player, _) {
                      // 5 个按钮在小屏上放不下时整体缩小（FittedBox 兜底）
                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _PanelAction(
                              icon: Icons.skip_previous_rounded,
                              label: '上一首',
                              onTap: player.playPrevious,
                            ),
                            _PanelAction(
                              icon: player.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              label: player.isPlaying ? '暂停' : '播放',
                              primary: true,
                              onTap: () {
                                WatchMotion.confirm();
                                player.togglePlayPause();
                              },
                            ),
                            _PanelAction(
                              icon: Icons.skip_next_rounded,
                              label: '下一首',
                              onTap: player.playNext,
                            ),
                            _LikeAction(),
                            _PanelAction(
                              icon: switch (player.playMode) {
                                PlayMode.shuffle => Icons.shuffle_rounded,
                                PlayMode.repeatOne => Icons.repeat_one_rounded,
                                _ => Icons.repeat_rounded,
                              },
                              label: '模式',
                              onTap: () {
                                const modes = [
                                  PlayMode.sequential,
                                  PlayMode.shuffle,
                                  PlayMode.repeatOne,
                                ];
                                final next = modes[
                                    (modes.indexOf(player.playMode) + 1) %
                                        modes.length];
                                player.setPlayMode(next);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  SizedBox(height: layout.bottomInset * 0.4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _PanelAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    final cs = Theme.of(context).colorScheme;
    final size = layout.touchTarget;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: primary ? cs.primary : cs.surfaceContainerHighest,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () {
            WatchMotion.tap();
            onTap();
          },
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: size * 0.46,
              color: primary ? cs.onPrimary : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// 面板内的收藏按钮（复用登录门控逻辑，面板内联实现避免路由冲突）。
class _LikeAction extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    final cs = Theme.of(context).colorScheme;
    final size = layout.touchTarget;

    return Consumer2<PlayerProvider, LikedSongsProvider>(
      builder: (context, player, likedSongs, _) {
        final song = player.currentSong;
        final isLiked = song != null && likedSongs.likedIds.contains(song.id);
        return Semantics(
          button: true,
          label: isLiked ? '取消收藏' : '收藏',
          child: Material(
            color: cs.surfaceContainerHighest,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () async {
                if (song == null) return;
                final auth = context.read<AuthProvider>();
                if (!auth.isLoggedIn) {
                  final goLogin = await showLoginRequiredDialog(context);
                  if (goLogin && context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const WatchLoginScreen()),
                    );
                  }
                  return;
                }
                await likedSongs.toggle(SongInfo(
                  id: song.id,
                  name: song.name,
                  hash: song.hash ?? '',
                  albumId: song.albumId,
                  audioId: 0,
                ));
                WatchMotion.confirm();
              },
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(
                  isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_outline_rounded,
                  size: size * 0.42,
                  color: isLiked ? cs.error : cs.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

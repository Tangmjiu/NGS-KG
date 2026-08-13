// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 收藏按钮 — 统一登录门控、动效与触觉反馈（播放器/FM 共用）

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../providers/auth_provider.dart';
import '../../providers/liked_songs_provider.dart';
import '../../utils/login_required_dialog.dart';
import '../screens/login_screen.dart';
import '../utils/watch_motion.dart';

/// 收藏（喜欢）切换按钮。
///
/// 内部处理：登录检查 → 收藏切换 → 触觉反馈。未登录时引导去登录页。
class WatchLikeButton extends StatelessWidget {
  final Song song;
  final double size;

  const WatchLikeButton({super.key, required this.song, this.size = 20});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Consumer<LikedSongsProvider>(
      builder: (context, likedSongs, _) {
        final isLiked = likedSongs.likedIds.contains(song.id);
        return IconButton(
          icon: AnimatedSwitcher(
            duration: WatchMotion.durShort3,
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
              key: ValueKey(isLiked),
              size: size,
              color: isLiked
                  ? colorScheme.error
                  : colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: () async {
            final auth = context.read<AuthProvider>();
            if (!auth.isLoggedIn) {
              final goLogin = await showLoginRequiredDialog(context);
              if (goLogin && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WatchLoginScreen(),
                  ),
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
        );
      },
    );
  }
}

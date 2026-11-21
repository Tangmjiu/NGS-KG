// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../providers/auth_provider.dart';
import '../../providers/liked_songs_provider.dart';
import '../../utils/error_dialog.dart';
import '../../utils/login_required_dialog.dart';
import '../utils/watch_motion.dart';
import 'watch_player_primitives.dart';

class WatchLikeButton extends StatefulWidget {
  const WatchLikeButton({super.key, required this.song, this.size = 20});
  final Song song;
  final double size;

  @override
  State<WatchLikeButton> createState() => _WatchLikeButtonState();
}

class _WatchLikeButtonState extends State<WatchLikeButton> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy || ModalRoute.of(context)?.isCurrent != true) return;
    setState(() => _busy = true);
    try {
      if (!context.read<AuthProvider>().isLoggedIn) {
        await showLoginRequiredDialog(context);
        return;
      }
      final song = widget.song;
      final ok = await context.read<LikedSongsProvider>().toggle(
        SongInfo(
          id: song.id,
          name: song.name,
          hash: song.hash ?? '',
          albumId: song.albumId,
          audioId: 0,
        ),
      );
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      if (ok) {
        WatchMotion.confirm();
      } else {
        showErrorDialog(title: '没能更新收藏', message: '请检查网络后再试。');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final liked = context.select<LikedSongsProvider, bool>(
      (songs) => songs.likedIds.contains(widget.song.id),
    );
    return Semantics(
      toggled: liked,
      child: IconButton(
        tooltip: liked ? '取消收藏' : '收藏',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        padding: EdgeInsets.zero,
        onPressed: _busy ? null : _toggle,
        icon: WatchSpringReveal(
          key: ValueKey(liked),
          child: Icon(
            liked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
            size: widget.size,
            color: liked ? colors.error : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

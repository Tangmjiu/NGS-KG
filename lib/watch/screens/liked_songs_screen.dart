// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 手表收藏歌曲列表

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/liked_songs_provider.dart';
import '../../../providers/player_provider.dart';
import '../widgets/watch_scaffold.dart';
import '../widgets/watch_scroll_list.dart';
import '../widgets/watch_song_tile.dart';
import 'login_screen.dart';

/// 收藏歌曲页：已登录显示列表（点击播放、右侧心形取消收藏），
/// 未登录引导登录。
class WatchLikedSongsScreen extends StatefulWidget {
  const WatchLikedSongsScreen({super.key});

  @override
  State<WatchLikedSongsScreen> createState() => _WatchLikedSongsScreenState();
}

class _WatchLikedSongsScreenState extends State<WatchLikedSongsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final liked = context.read<LikedSongsProvider>();
      if (!liked.isLoaded) liked.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLoggedIn) return _buildNotLoggedIn();

    return WatchScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Text(
              '我的收藏',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Consumer2<LikedSongsProvider, PlayerProvider>(
              builder: (context, liked, player, _) {
                if (!liked.isLoaded) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  );
                }
                if (liked.likedSongs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_border_rounded,
                          size: 40,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '暂无收藏歌曲',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                        ),
                      ],
                    ),
                  );
                }
                return WatchScrollList(
                  itemCount: liked.likedSongs.length,
                  itemExtent: 52,
                  bottomPadding: 24,
                  itemBuilder: (context, index) {
                    final song = liked.likedSongs[index];
                    return WatchSongTile.fromSong(
                      song: song,
                      isPlaying: player.currentSong?.id == song.id,
                      onTap: () => context
                          .read<PlayerProvider>()
                          .playSong(song, playlist: liked.likedSongs),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.favorite_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => liked.toggle(SongInfo(
                          id: song.id,
                          name: song.name,
                          hash: song.hash ?? '',
                          albumId: song.albumId,
                          audioId: 0,
                        )),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotLoggedIn() {
    final theme = Theme.of(context);
    return WatchScaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 40,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              '登录后可查看收藏',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WatchLoginScreen()),
              ),
              child: const Text('登录'),
            ),
          ],
        ),
      ),
    );
  }
}

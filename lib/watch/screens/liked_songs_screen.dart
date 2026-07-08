// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 圆屏收藏歌曲列表

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/liked_songs_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/watch_scroll_list.dart';
import '../widgets/watch_song_tile.dart';
import '../widgets/round_safe_area.dart';
import 'login_screen.dart';

/// 手表版收藏歌曲页面
///
/// 显示用户已收藏的歌曲列表，支持点击播放和取消收藏。
/// 未登录时提示登录。
class WatchLikedSongsScreen extends StatefulWidget {
  const WatchLikedSongsScreen({super.key});

  @override
  State<WatchLikedSongsScreen> createState() => _WatchLikedSongsScreenState();
}

class _WatchLikedSongsScreenState extends State<WatchLikedSongsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadIfNeeded());
  }

  void _loadIfNeeded() {
    final liked = context.read<LikedSongsProvider>();
    if (!liked.isLoaded) {
      liked.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLoggedIn) {
      return _buildNotLoggedIn();
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('我的收藏', style: TextStyle(fontSize: 14)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<LikedSongsProvider>(
        builder: (context, liked, _) {
          if (!liked.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (liked.likedSongs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border_rounded, size: 48,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text('暂无收藏歌曲',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            );
          }
          return RoundSafeArea(
            child: WatchScrollList(
              itemCount: liked.likedSongs.length,
              itemBuilder: (context, index) {
                final song = liked.likedSongs[index];
                final player = context.watch<PlayerProvider>();
                final isCurrent = player.currentSong?.id == song.id;
                return WatchSongTile(
                  title: song.name,
                  artist: song.artistDisplay,
                  isPlaying: isCurrent,
                  onTap: () {
                    final player = context.read<PlayerProvider>();
                    player.playSong(song, playlist: liked.likedSongs);
                  },
                  trailing: IconButton(
                    icon: Icon(Icons.favorite_rounded, size: 18,
                      color: Theme.of(context).colorScheme.error),
                    onPressed: () async {
                      final songInfo = SongInfo(
                        id: song.id,
                        name: song.name,
                        hash: song.hash ?? '',
                        albumId: song.albumId,
                        audioId: 0,
                      );
                      await liked.toggle(songInfo);
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotLoggedIn() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('我的收藏', style: TextStyle(fontSize: 14)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border_rounded, size: 48,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('登录后可查看收藏',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WatchLoginScreen()),
                );
              },
              child: const Text('登录'),
            ),
          ],
        ),
      ),
    );
  }
}

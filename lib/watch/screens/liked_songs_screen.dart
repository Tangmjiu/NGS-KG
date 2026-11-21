// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/liked_songs_provider.dart';
import '../../providers/player_provider.dart';
import '../widgets/watch_scaffold.dart';
import '../widgets/watch_scroll_list.dart';
import '../widgets/watch_song_tile.dart';
import 'login_screen.dart';

class WatchLikedSongsScreen extends StatefulWidget {
  const WatchLikedSongsScreen({super.key});
  @override
  State<WatchLikedSongsScreen> createState() => _WatchLikedSongsScreenState();
}

class _WatchLikedSongsScreenState extends State<WatchLikedSongsScreen> {
  int? _user;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context);
    final next = auth.isLoggedIn ? auth.user?.userId : null;
    if (_user == next) return;
    _user = next;
    _failed = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          next != null &&
          _user == next &&
          !context.read<LikedSongsProvider>().isLoaded) {
        _load();
      }
    });
  }

  Future<void> _load() async {
    final liked = context.read<LikedSongsProvider>();
    final user = _user;
    if (_failed) setState(() => _failed = false);
    await liked.load();
    if (mounted && _user == user) setState(() => _failed = !liked.isLoaded);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final liked = context.watch<LikedSongsProvider>();
    final current = context.select((PlayerProvider p) => p.currentSong);
    final songs = liked.likedSongs;
    Widget body;
    if (!auth.isLoggedIn) {
      body = WatchCatalogNotice(
        '登录后查看收藏',
        icon: Icons.favorite_border_rounded,
        action: FilledButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const WatchLoginScreen()),
          ),
          child: const Text('登录'),
        ),
      );
    } else if (!liked.isLoaded) {
      body = _failed
          ? WatchCatalogNotice(
              '收藏没能加载',
              icon: Icons.cloud_off_rounded,
              action: TextButton(onPressed: _load, child: const Text('重试')),
            )
          : const WatchCatalogNotice('正在读取收藏', busy: true);
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: songs.isEmpty
            ? const WatchCatalogNotice(
                '还没有收藏歌曲',
                icon: Icons.favorite_border_rounded,
              )
            : WatchScrollList(
                itemExtent: 52,
                itemCount: songs.length,
                itemBuilder: (context, i) {
                  final song = songs[i];
                  return WatchSongTile.fromSong(
                    song: song,
                    isPlaying: watchSameSong(current, song),
                    onTap: () => context.read<PlayerProvider>().playSong(
                      song,
                      playlist: List.of(songs),
                    ),
                    trailing: IconButton(
                      tooltip: '取消收藏',
                      icon: const Icon(Icons.favorite_rounded, size: 17),
                      onPressed: () async {
                        final ok = await liked.toggle(
                          SongInfo(
                            id: song.id,
                            name: song.name,
                            hash: song.hash ?? '',
                            albumId: song.albumId,
                            audioId: 0,
                          ),
                        );
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('取消收藏失败')),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
      );
    }
    return WatchScaffold(
      body: Column(
        children: [
          WatchCatalogTitle(
            '我的收藏',
            caption: auth.isLoggedIn && liked.isLoaded
                ? '${songs.length} 首'
                : null,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

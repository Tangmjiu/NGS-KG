// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 手表歌单列表 + 歌单歌曲页（全屏页取代 BottomSheet，符合 Wear 规范）

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/playlist.dart';
import '../../providers/auth_provider.dart';
import '../../providers/liked_songs_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../utils/watch_layout.dart';
import '../widgets/round_list_tile.dart';
import '../widgets/watch_scaffold.dart';
import '../widgets/watch_scroll_list.dart';
import '../widgets/watch_song_tile.dart';

/// 手表端歌单列表（外壳 PageView 第 2 页）。
class WatchPlaylistListScreen extends StatefulWidget {
  const WatchPlaylistListScreen({super.key});

  @override
  State<WatchPlaylistListScreen> createState() =>
      _WatchPlaylistListScreenState();
}

class _WatchPlaylistListScreenState extends State<WatchPlaylistListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn && auth.user?.userId != null) {
      await Future.wait([
        context.read<PlaylistProvider>().fetchUserPlaylist(auth.user!.userId),
        context.read<LikedSongsProvider>().load(),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    final auth = context.watch<AuthProvider>();
    final playlists = context.watch<PlaylistProvider>().userPlaylists;

    if (!auth.isLoggedIn) {
      return Padding(
        padding: EdgeInsets.only(top: layout.topInset),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.queue_music_rounded,
                size: 36,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
              ),
              const SizedBox(height: 8),
              Text(
                '登录后查看歌单',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: layout.topInset),
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: playlists.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 60),
                  Center(
                    child: Text(
                      '暂无歌单',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                    ),
                  ),
                ],
              )
            : WatchScrollList(
                itemCount: playlists.length + 1,
                itemExtent: 54,
                topPadding: 4,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '我的歌单',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  }
                  final playlist = playlists[index - 1];
                  return RoundListTile(
                    title: playlist.name,
                    subtitle: '${playlist.trackCount} 首',
                    leading: const Icon(Icons.queue_music_rounded),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            WatchPlaylistSongsScreen(playlist: playlist),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// 歌单歌曲页（推入式全屏页，支持右滑返回 + 表冠滚动）
class WatchPlaylistSongsScreen extends StatefulWidget {
  final Playlist playlist;

  const WatchPlaylistSongsScreen({super.key, required this.playlist});

  @override
  State<WatchPlaylistSongsScreen> createState() =>
      _WatchPlaylistSongsScreenState();
}

class _WatchPlaylistSongsScreenState extends State<WatchPlaylistSongsScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // initState 阶段处于父级 build 锁内，setState/notifyListeners 会炸，推迟到首帧后
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    // 与安卓端一致：优先用 globalCollectionId，否则按 collection_3_{createUserId}_{listid}_0 组装
    final p = widget.playlist;
    final gcId = p.globalCollectionId ??
        (p.createUserId != null
            ? 'collection_3_${p.createUserId}_${p.id}_0'
            : p.id.toString());
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<PlaylistProvider>().fetchPlaylistDetail(gcId);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = context.watch<PlaylistProvider>().currentPlaylist;
    final songs = detail?.songs ?? [];

    return WatchScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.playlist.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (songs.isNotEmpty)
                  Text(
                    '${songs.length} 首',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildContent(songs)),
        ],
      ),
    );
  }

  Widget _buildContent(List songs) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 32, color: Theme.of(context).colorScheme.error),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (songs.isEmpty) {
      return Center(
        child: Text(
          '暂无歌曲',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
        ),
      );
    }
    return WatchScrollList(
      itemCount: songs.length,
      itemExtent: 52,
      bottomPadding: 24,
      itemBuilder: (context, index) {
        final song = songs[index];
        return Consumer<PlayerProvider>(
          builder: (context, player, _) => WatchSongTile.fromSong(
            song: song,
            isPlaying: player.currentSong?.id == song.id,
            onTap: () => context
                .read<PlayerProvider>()
                .playSong(song, playlist: songs.cast()),
          ),
        );
      },
    );
  }
}

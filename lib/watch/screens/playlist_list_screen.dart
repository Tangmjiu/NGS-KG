// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../providers/auth_provider.dart';
import '../../providers/liked_songs_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../widgets/watch_scaffold.dart';
import '../widgets/watch_scroll_list.dart';
import '../widgets/watch_song_tile.dart';
import 'login_screen.dart';

class WatchPlaylistListScreen extends StatefulWidget {
  const WatchPlaylistListScreen({super.key});
  @override
  State<WatchPlaylistListScreen> createState() =>
      _WatchPlaylistListScreenState();
}

class _WatchPlaylistListScreenState extends State<WatchPlaylistListScreen> {
  int? _userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context);
    final next = auth.isLoggedIn ? auth.user?.userId : null;
    if (next == _userId) return;
    _userId = next;
    if (next != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _userId == next) _load();
      });
    }
  }

  Future<void> _load() async {
    final user = _userId;
    if (user == null) return;
    await Future.wait([
      context.read<PlaylistProvider>().fetchUserPlaylist(user),
      context.read<LikedSongsProvider>().load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<PlaylistProvider>();
    final playlists = provider.userPlaylists;
    return WatchScaffold(
      body: Column(
        children: [
          const WatchCatalogTitle('我的歌单'),
          Expanded(
            child: !auth.isLoggedIn
                ? WatchCatalogNotice(
                    '登录后查看歌单',
                    icon: Icons.library_music_outlined,
                    action: FilledButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const WatchLoginScreen(),
                        ),
                      ),
                      child: const Text('登录'),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: playlists.isEmpty
                        ? WatchCatalogNotice(
                            provider.isLoading ? '正在读取歌单' : '还没有歌单',
                            icon: Icons.library_music_outlined,
                            busy: provider.isLoading,
                          )
                        : WatchScrollList(
                            itemCount: playlists.length,
                            itemExtent: 54,
                            itemBuilder: (_, index) =>
                                _PlaylistPill(playlist: playlists[index]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistPill extends StatelessWidget {
  const _PlaylistPill({required this.playlist});
  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = playlist.coverUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: theme.colorScheme.secondaryContainer,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: const Alignment(.72, 0),
              child: Icon(
                Icons.library_music_rounded,
                color: theme.colorScheme.onSecondaryContainer.withValues(
                  alpha: .4,
                ),
                size: 42,
              ),
            ),
            if (cover?.isNotEmpty == true)
              CachedNetworkImage(
                imageUrl: cover!,
                fit: BoxFit.cover,
                memCacheWidth: 320,
                fadeInDuration: Duration.zero,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xDD000000),
                    Color(0x99000000),
                    Color(0x45000000),
                  ],
                ),
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        WatchPlaylistSongsScreen(playlist: playlist),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${playlist.trackCount} 首',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WatchPlaylistSongsScreen extends StatefulWidget {
  const WatchPlaylistSongsScreen({super.key, required this.playlist});
  final Playlist playlist;
  @override
  State<WatchPlaylistSongsScreen> createState() =>
      _WatchPlaylistSongsScreenState();
}

class _WatchPlaylistSongsScreenState extends State<WatchPlaylistSongsScreen> {
  bool _loading = true;
  List<Song>? _songs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final playlist = widget.playlist;
    final id =
        playlist.globalCollectionId ??
        (playlist.createUserId != null
            ? 'collection_3_${playlist.createUserId}_${playlist.id}_0'
            : playlist.id.toString());
    setState(() => _loading = true);
    final provider = context.read<PlaylistProvider>();
    List<Song>? result;
    try {
      await provider.fetchPlaylistDetail(id);
      result = provider.currentPlaylist?.songs;
    } catch (_) {
      result = null;
    }
    if (mounted) {
      setState(() {
        _songs = result;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = context.select((PlayerProvider p) => p.currentSong);
    final songs = _songs;
    return WatchScaffold(
      body: Column(
        children: [
          WatchCatalogTitle(
            widget.playlist.name,
            caption: songs == null ? null : '${songs.length} 首',
          ),
          Expanded(
            child: _loading
                ? const WatchCatalogNotice('正在读取歌曲', busy: true)
                : songs == null
                ? WatchCatalogNotice(
                    '歌单没能加载',
                    icon: Icons.cloud_off_rounded,
                    action: TextButton(
                      onPressed: _load,
                      child: const Text('重试'),
                    ),
                  )
                : songs.isEmpty
                ? const WatchCatalogNotice(
                    '歌单里还没有歌',
                    icon: Icons.queue_music_rounded,
                  )
                : WatchScrollList(
                    itemCount: songs.length + 1,
                    itemExtent: 52,
                    itemBuilder: (context, index) {
                      final player = context.read<PlayerProvider>();
                      if (index == 0) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton.filledTonal(
                              tooltip: '随机播放',
                              icon: const Icon(Icons.shuffle_rounded),
                              onPressed: () {
                                final shuffled = List<Song>.of(songs)
                                  ..shuffle();
                                player.playSong(
                                  shuffled.first,
                                  playlist: shuffled,
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              tooltip: '播放全部',
                              icon: const Icon(Icons.play_arrow_rounded),
                              onPressed: () =>
                                  player.playSong(songs.first, playlist: songs),
                            ),
                          ],
                        );
                      }
                      final song = songs[index - 1];
                      return WatchSongTile.fromSong(
                        song: song,
                        isPlaying: watchSameSong(current, song),
                        onTap: () => player.playSong(song, playlist: songs),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

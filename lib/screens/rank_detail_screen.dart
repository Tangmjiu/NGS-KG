// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../ui/components/song_tile.dart';
import '../ui/components/player_bottom_padding.dart';
import '../ui/app_ui.dart';
import '../ui/components/collection_header.dart';

class RankDetailScreen extends StatefulWidget {
  final int rankId;
  final String? rankName;

  const RankDetailScreen({super.key, required this.rankId, this.rankName});

  @override
  State<RankDetailScreen> createState() => _RankDetailScreenState();
}

class _RankDetailScreenState extends State<RankDetailScreen> {
  final MusicService _musicService = MusicService();
  List<Song>? _songs;
  bool _isLoading = true;
  bool _loadFailed = false;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loadFailed = false;
      _isLoading = _songs == null || _songs!.isEmpty;
    });
    try {
      final songs = await _musicService.getRankAudios(widget.rankId);
      if (mounted) {
        setState(() {
          _songs = songs;
          _total = songs.length;
          _isLoading = false;
        });
      }
    } catch (e, s) {
      Log.e('rank_detail_screen', 'error', e, s);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final songs = _songs ?? <Song>[];
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('排行榜')),
      body: AppPageBody(
          child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
                child: CollectionHeader(
              title: widget.rankName ?? '排行榜',
              kind: '排行榜',
              subtitle: '共 $_total 首歌曲',
              coverUrl: songs.firstOrNull?.albumCoverUrl,
              fallbackIcon: Icons.equalizer_rounded,
              actions: [
                FilledButton.icon(
                  onPressed: songs.isEmpty
                      ? null
                      : () => context
                          .read<PlayerProvider>()
                          .playSong(songs.first, playlist: songs),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('播放全部'),
                )
              ],
            )),
            if (_isLoading)
              const SliverToBoxAdapter(
                  child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: AppLoadingIndicator())))
            else if (songs.isEmpty)
              SliverToBoxAdapter(
                  child: AppEmptyState(
                icon: _loadFailed
                    ? Icons.cloud_off_rounded
                    : Icons.equalizer_rounded,
                title: _loadFailed ? '榜单暂时无法加载' : '榜单暂无歌曲',
                action: _loadFailed
                    ? FilledButton.tonalIcon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('重试'))
                    : null,
              ))
            else
              SliverList(
                  delegate: SliverChildBuilderDelegate(
                      (context, index) => Row(children: [
                            SizedBox(
                                width: 44,
                                child: Text('${index + 1}',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                            color: index < 3
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme
                                                    .onSurfaceVariant))),
                            Expanded(
                                child: SongTile(
                                    song: songs[index],
                                    onTap: (song) => context
                                        .read<PlayerProvider>()
                                        .playSong(song, playlist: songs))),
                          ]),
                      childCount: songs.length)),
            const SliverToBoxAdapter(
                child: PlayerBottomPadding(showLabel: false)),
          ],
        ),
      )),
    );
  }
}

// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/rank_entry.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../services/music_service.dart';
import '../widgets/watch_cover_art.dart';
import '../widgets/watch_scaffold.dart';
import '../widgets/watch_scroll_list.dart';
import '../widgets/watch_song_tile.dart';

class WatchRankListScreen extends StatefulWidget {
  const WatchRankListScreen({super.key});
  @override
  State<WatchRankListScreen> createState() => _WatchRankListScreenState();
}

class _WatchRankListScreenState extends State<WatchRankListScreen> {
  late Future<List<RankEntry>> _result;

  @override
  void initState() {
    super.initState();
    _result = context.read<MusicService>().getRankList();
  }

  Future<void> _reload() async {
    final result = context.read<MusicService>().getRankList();
    setState(() {
      _result = result;
    });
    // FutureBuilder presents the exception and keeps a retry target on screen.
    await result.then<void>((_) {}, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WatchScaffold(
      body: Column(
        children: [
          const WatchCatalogTitle('排行榜'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: FutureBuilder<List<RankEntry>>(
                future: _result,
                builder: (_, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const WatchCatalogNotice('正在读取榜单', busy: true);
                  }
                  if (snapshot.hasError) {
                    return WatchCatalogNotice(
                      '榜单没能加载',
                      icon: Icons.cloud_off_rounded,
                      action: TextButton(
                        onPressed: _reload,
                        child: const Text('重试'),
                      ),
                    );
                  }
                  final ranks = snapshot.data ?? const <RankEntry>[];
                  if (ranks.isEmpty) {
                    return const WatchCatalogNotice(
                      '暂无榜单',
                      icon: Icons.leaderboard_outlined,
                    );
                  }
                  return WatchScrollList(
                    itemExtent: 52,
                    itemCount: ranks.length,
                    itemBuilder: (context, i) {
                      final rank = ranks[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Material(
                          color: theme.colorScheme.surfaceContainerHigh,
                          shape: const StadiumBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    WatchRankSongsScreen(rank: rank),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(6, 0, 8, 0),
                              child: Row(
                                children: [
                                  WatchCoverArt(
                                    imageUrl: rank.coverUrl,
                                    size: 32,
                                    round: true,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      rank.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WatchRankSongsScreen extends StatefulWidget {
  const WatchRankSongsScreen({super.key, required this.rank});
  final RankEntry rank;
  @override
  State<WatchRankSongsScreen> createState() => _WatchRankSongsScreenState();
}

class _WatchRankSongsScreenState extends State<WatchRankSongsScreen> {
  late Future<List<Song>> _result;

  Future<List<Song>> _fetch() =>
      context.read<MusicService>().getRankAudios(widget.rank.id, pageSize: 10);

  @override
  void initState() {
    super.initState();
    _result = _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final current = context.select((PlayerProvider p) => p.currentSong);
    return WatchScaffold(
      body: Column(
        children: [
          WatchCatalogTitle(widget.rank.name, caption: '前 10 首'),
          Expanded(
            child: FutureBuilder<List<Song>>(
              future: _result,
              builder: (_, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const WatchCatalogNotice('正在读取歌曲', busy: true);
                }
                if (snapshot.hasError) {
                  return WatchCatalogNotice(
                    '榜单歌曲没能加载',
                    icon: Icons.cloud_off_rounded,
                    action: TextButton(
                      onPressed: () => setState(() {
                        _result = _fetch();
                      }),
                      child: const Text('重试'),
                    ),
                  );
                }
                final songs = snapshot.data ?? const <Song>[];
                if (songs.isEmpty) {
                  return const WatchCatalogNotice(
                    '这个榜单里还没有歌',
                    icon: Icons.music_note_outlined,
                  );
                }
                return WatchScrollList(
                  itemCount: songs.length,
                  itemExtent: 52,
                  itemBuilder: (context, i) {
                    final song = songs[i];
                    return WatchSongTile.fromSong(
                      song: song,
                      rank: i + 1,
                      isPlaying: watchSameSong(current, song),
                      onTap: () {
                        context.read<PlayerProvider>().playSong(
                          song,
                          playlist: songs,
                        );
                        Navigator.pop(context);
                      },
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
}

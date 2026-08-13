// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 手表排行榜 — 榜单列表 + Top10 歌曲页（全屏页取代 BottomSheet）

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/rank_entry.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../services/music_service.dart';
import '../utils/watch_layout.dart';
import '../widgets/round_list_tile.dart';
import '../widgets/watch_cover_art.dart';
import '../widgets/watch_scaffold.dart';
import '../widgets/watch_scroll_list.dart';
import '../widgets/watch_song_tile.dart';

/// 手表版排行榜列表（外壳 PageView 第 3 页）。
class WatchRankListScreen extends StatefulWidget {
  const WatchRankListScreen({super.key});

  @override
  State<WatchRankListScreen> createState() => _WatchRankListScreenState();
}

class _WatchRankListScreenState extends State<WatchRankListScreen> {
  List<RankEntry>? _entries;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // initState 处于 build 锁内，setState 需推迟到首帧后
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ranks = await context.read<MusicService>().getRankList();
      if (!mounted) return;
      setState(() {
        _entries = ranks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(top: layout.topInset),
      child: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 48),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 32, color: theme.colorScheme.error),
                const SizedBox(height: 6),
                Text('加载失败', style: theme.textTheme.bodyMedium),
                TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('重试'),
                ),
              ],
            ),
          ),
        ],
      );
    }
    final entries = _entries ?? [];
    if (entries.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          Center(
            child: Text(
              '暂无排行榜',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      );
    }
    return WatchScrollList(
      itemCount: entries.length + 1,
      itemExtent: 54,
      topPadding: 4,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '排行榜',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          );
        }
        final rank = entries[index - 1];
        return RoundListTile(
          title: rank.name,
          leading:
              WatchCoverArt(imageUrl: rank.coverUrl, size: 32, round: false),
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WatchRankSongsScreen(rank: rank),
            ),
          ),
        );
      },
    );
  }
}

/// 榜单歌曲页（Top 10，推入式全屏页）
class WatchRankSongsScreen extends StatefulWidget {
  final RankEntry rank;

  const WatchRankSongsScreen({super.key, required this.rank});

  @override
  State<WatchRankSongsScreen> createState() => _WatchRankSongsScreenState();
}

class _WatchRankSongsScreenState extends State<WatchRankSongsScreen> {
  List<Song>? _songs;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // initState 处于 build 锁内，setState 需推迟到首帧后
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final songs = await context
          .read<MusicService>()
          .getRankAudios(widget.rank.id, pageSize: 10);
      if (!mounted) return;
      setState(() {
        _songs = songs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final songs = _songs ?? const <Song>[];

    return WatchScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Text(
              widget.rank.name,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(child: _buildContent(theme, songs)),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, List<Song> songs) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 32, color: theme.colorScheme.error),
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
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
        return WatchSongTile.fromSong(
          song: song,
          leading: SizedBox(
            width: 20,
            child: Text(
              '${index + 1}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: index < 3
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          onTap: () {
            context.read<PlayerProvider>().playSong(song, playlist: songs);
            Navigator.pop(context);
          },
        );
      },
    );
  }
}

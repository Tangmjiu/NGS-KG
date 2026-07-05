// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 排行榜列表 — 展示排行榜分类，点击展开 Top 10 歌曲

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wear_plus/wear_plus.dart';

import '../../models/rank_entry.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../services/music_service.dart';
import '../widgets/round_safe_area.dart';
import '../widgets/watch_song_tile.dart';

/// 手表版排行榜列表
class WatchRankListScreen extends StatefulWidget {
  const WatchRankListScreen({super.key});

  @override
  State<WatchRankListScreen> createState() => _WatchRankListScreenState();
}

class _WatchRankListScreenState extends State<WatchRankListScreen> {
  List<RankEntry>? _rankEntries;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRanks();
  }

  Future<void> _loadRanks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final ranks = await context.read<MusicService>().getRankList();
      if (!mounted) return;
      setState(() {
        _rankEntries = ranks;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _openRankSongs(RankEntry rank) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RankSongSheet(rank: rank),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 32, color: theme.colorScheme.error),
              const SizedBox(height: 8),
              Text('加载失败', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _loadRanks,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final entries = _rankEntries ?? [];

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.leaderboard_outlined,
                size: 40,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text('暂无排行榜', style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    return RoundSafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 12, bottom: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                '排行榜',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            ...entries.map(
              (rank) => _RankListTile(
                rank: rank,
                onTap: () => _openRankSongs(rank),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 排行榜列表项 — 显示封面、名称、箭头
class _RankListTile extends StatelessWidget {
  final RankEntry rank;
  final VoidCallback onTap;

  const _RankListTile({
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // 封面缩略图
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 40,
                  height: 40,
                  color: theme.colorScheme.primaryContainer,
                  child: rank.coverUrl != null
                      ? Image.network(
                          rank.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.leaderboard,
                            size: 20,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        )
                      : Icon(
                          Icons.leaderboard,
                          size: 20,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // 排行榜名称
              Expanded(
                child: Text(
                  rank.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 排行榜歌曲列表 BottomSheet — 加载并显示 Top 10 歌曲
class _RankSongSheet extends StatefulWidget {
  final RankEntry rank;

  const _RankSongSheet({required this.rank});

  @override
  State<_RankSongSheet> createState() => _RankSongSheetState();
}

class _RankSongSheetState extends State<_RankSongSheet> {
  List<Song>? _songs;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 延迟加载以确保 context 已挂载
    Future.microtask(_loadSongs);
  }

  Future<void> _loadSongs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final songs = await context
          .read<MusicService>()
          .getRankAudios(widget.rank.id, pageSize: 10);
      if (!mounted) return;
      setState(() {
        _songs = songs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _playSong(Song song) {
    final allSongs = _songs ?? [];
    context.read<PlayerProvider>().playSong(song, playlist: allSongs);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final isRound = WatchShape.of(context) == WearShape.round;
    final sheetHeight = isRound ? 0.45 : 0.55;
    return Container(
      height: MediaQuery.of(context).size.height * sheetHeight,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示条
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 排行榜标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              widget.rank.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 1),
          // 内容区域
          Expanded(child: _buildContent(theme)),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 32, color: theme.colorScheme.error),
              const SizedBox(height: 8),
              Text('加载失败', style: theme.textTheme.bodyMedium),
              TextButton.icon(
                onPressed: _loadSongs,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final songs = _songs ?? [];

    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_off_outlined,
                size: 32,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text('暂无歌曲', style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemCount: songs.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
      itemBuilder: (_, i) {
        final song = songs[i];
        return WatchSongTile(
          title: song.name,
          artist: song.artistDisplay,
          trailing: SizedBox(
            width: 24,
            child: Text(
              '${i + 1}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: i < 3
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          onTap: () => _playSong(song),
        );
      },
    );
  }
}

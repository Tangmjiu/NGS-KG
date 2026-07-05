// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 圆屏歌单列表 — 显示收藏歌曲和用户歌单

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../providers/liked_songs_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../widgets/watch_song_tile.dart';

/// 手表端歌单 / 收藏列表页面。
///
/// 显示：
/// 1. 收藏歌曲卡片（带爱心图标 + 数量，点击弹出歌曲列表）
/// 2. 我的歌单列表（显示歌单名 + 歌曲数，点击弹出歌曲列表）
///
/// 所有内容在 [SingleChildScrollView] 中纵向滚动，适配圆屏。
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
    // 延迟一帧，确保 context 已挂载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  /// 初始加载数据
  void _loadData() {
    if (!mounted) return;
    context.read<PlaylistProvider>().fetchUserPlaylist(null);
    context.read<LikedSongsProvider>().load();
  }

  // ─────────────────────────────────────────────────────────────
  // 页面主体
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlaylistProvider, LikedSongsProvider>(
      builder: (context, playlistProv, likedProv, _) {
        final likedCount = likedProv.likedIds.length;
        final playlists = playlistProv.userPlaylists;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── 收藏歌曲 ───
              _buildLikedSongsCard(context, likedCount, likedProv),
              const SizedBox(height: 8),

              // ─── 我的歌单 ───
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  '我的歌单',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),

              // 歌单列表 / 空状态
              if (playlists.isEmpty)
                _buildEmptyState(context, '暂无歌单')
              else
                ...playlists.map(
                  (p) => _buildPlaylistItem(context, p, playlistProv),
                ),

              // 底部留白，避免 MiniPlayer 遮挡
              const SizedBox(height: 60),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 子组件
  // ─────────────────────────────────────────────────────────────

  /// 收藏歌曲卡片 — 爱心图标 + "收藏歌曲" + 数量
  Widget _buildLikedSongsCard(
      BuildContext context, int count, LikedSongsProvider likedProv) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showLikedSongsSheet(context, likedProv),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // 爱心图标
              Icon(
                Icons.favorite,
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              // 标题
              Expanded(
                child: Text(
                  '收藏歌曲',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // 数量徽章
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 歌单项 — 图标 + 歌单名 + 歌曲数
  Widget _buildPlaylistItem(
      BuildContext context, Playlist playlist, PlaylistProvider provider) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showPlaylistSheet(context, playlist, provider),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // 歌单图标
              Icon(
                Icons.queue_music_rounded,
                size: 24,
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 10),
              // 歌单名
              Expanded(
                child: Text(
                  playlist.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // 歌曲数
              Text(
                '${playlist.trackCount}首',
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 4),
              // 箭头
              Icon(
                Icons.chevron_right,
                size: 18,
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 空状态占位
  Widget _buildEmptyState(BuildContext context, String message) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 36,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Bottom Sheet — 歌曲列表
  // ─────────────────────────────────────────────────────────────

  /// 弹出收藏歌曲列表 Bottom Sheet
  void _showLikedSongsSheet(
      BuildContext context, LikedSongsProvider likedProv) {
    final count = likedProv.likedIds.length;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Icon(Icons.favorite, size: 40,
              color: Theme.of(ctx).colorScheme.primary),
            const SizedBox(height: 12),
            Text('收藏歌曲',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('已收藏 $count 首歌曲',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6))),
            if (count == 0) ...[
              const SizedBox(height: 12),
              Text('去发现页面收藏喜欢的歌曲吧',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.4))),
            ],
          ],
        ),
      ),
    );
  }

  /// 弹出歌单歌曲列表 Bottom Sheet
  void _showPlaylistSheet(BuildContext context, Playlist playlist,
      PlaylistProvider provider) {
    final player = context.read<PlayerProvider>();
    provider.fetchPlaylistDetail(playlist.id.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final detail = provider.currentPlaylist;
        final songs = detail?.songs ?? <Song>[];

        // ── 加载/空状态 ──
        if (songs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                '暂无歌曲',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ),
          );
        }

        // ── 歌曲列表 ──
        return _buildSongSheetContent(
          ctx,
          title: playlist.name,
          icon: Icons.queue_music_rounded,
          iconColor: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7),
          songCount: songs.length,
          child: ListView.builder(
            itemCount: songs.length,
            itemBuilder: (ctx, index) {
              final song = songs[index];
              final isPlaying = player.currentSong?.id == song.id;
              return WatchSongTile.fromSong(
                song: song,
                isPlaying: isPlaying,
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<PlayerProvider>().playSong(song, playlist: songs);
                },
              );
            },
          ),
        );
      },
    );
  }

  /// Bottom Sheet 通用布局：拖拽手柄 → 标题栏 → 可滚动歌曲列表
  Widget _buildSongSheetContent(
    BuildContext ctx, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required int songCount,
    required Widget child,
  }) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title,
                      style: Theme.of(ctx).textTheme.titleMedium,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text('$songCount首',
                    style: Theme.of(ctx).textTheme.bodySmall),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: child is ListView
                  ? child
                  : ListView(controller: scrollController, children: [child]),
            ),
          ],
        );
      },
    );
  }
}

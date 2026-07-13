// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 圆屏歌单列表 — 显示收藏歌曲和用户歌单

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../providers/auth_provider.dart';
import '../../providers/liked_songs_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import 'package:wear_plus/wear_plus.dart';

import '../widgets/round_safe_area.dart';
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

  // ─────────────────────────────────────────────────────────────
  // 页面主体
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final playlists = context.watch<PlaylistProvider>().userPlaylists;

    return RoundSafeArea(
      child: RefreshIndicator(
        onRefresh: () => _loadData(),
        child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              (p) => _buildPlaylistItem(context, p),
            ),

          // 底部留白，避免 MiniPlayer 遮挡
          const SizedBox(height: 60),
        ],
        ),
      ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 子组件
  // ─────────────────────────────────────────────────────────────

  /// 歌单项 — 图标 + 歌单名 + 歌曲数
  Widget _buildPlaylistItem(
      BuildContext context, Playlist playlist) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showPlaylistSheet(context, playlist),
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

  /// 弹出歌单歌曲列表 Bottom Sheet
  void _showPlaylistSheet(BuildContext context, Playlist playlist) {
    final provider = context.read<PlaylistProvider>();
    final player = context.read<PlayerProvider>();
    final future = provider.fetchPlaylistDetail(playlist.id.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FutureBuilder<void>(
          future: future,
          builder: (ctx, snapshot) {
            // ── 加载中 ──
            if (snapshot.connectionState != ConnectionState.done) {
              return _buildSheetLoading(ctx);
            }

            final detail = provider.currentPlaylist;
            final songs = detail?.songs ?? <Song>[];

            // ── 空 / 错误状态 ──
            if (songs.isEmpty) {
              return _buildSheetEmpty(ctx);
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
      },
    );
  }

  /// Bottom Sheet 加载态
  Widget _buildSheetLoading(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: CircularProgressIndicator(
          color: Theme.of(ctx).colorScheme.primary,
        ),
      ),
    );
  }

  /// Bottom Sheet 空状态
  Widget _buildSheetEmpty(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          '暂无歌曲',
          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
              color: Theme.of(ctx)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5)),
        ),
      ),
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
    final isRound = WatchShape.of(ctx) == WearShape.round;
    return DraggableScrollableSheet(
      initialChildSize: isRound ? 0.5 : 0.7,
      minChildSize: isRound ? 0.3 : 0.4,
      maxChildSize: isRound ? 0.75 : 0.92,
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

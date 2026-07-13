// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 圆屏私人 FM 电台界面 — 播放/暂停、下一首、收藏

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../models/song.dart';
import '../../../models/song_mapper.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/liked_songs_provider.dart';
import '../../../services/music_service.dart';
import '../../../utils/logger.dart';
import '../utils/watch_motion.dart';
import '../widgets/round_safe_area.dart';

/// 手表版私人 FM 电台屏幕
///
/// 加载酷狗私人 FM 推荐列表并逐首播放。
/// 包含：歌曲信息显示、播放/暂停、下一首切换、收藏按钮。
/// 适配圆形屏幕，深色背景极简布局。
class WatchFmScreen extends StatefulWidget {
  const WatchFmScreen({super.key});

  @override
  State<WatchFmScreen> createState() => _WatchFmScreenState();
}

class _WatchFmScreenState extends State<WatchFmScreen> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFmSongs();
  }

  // ═══════════════════════════════════════════════════════════
  //  数据加载
  // ═══════════════════════════════════════════════════════════

  /// 首次加载私人 FM 推荐列表
  Future<void> _loadFmSongs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final musicService = context.read<MusicService>();
      final raw = await musicService.getPersonalFm();
      final songs = raw
          .map((e) => SongMapper.fromFmJson(e))
          .whereType<Song>()
          .toList();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // 进入 FM 模式并自动播放第一首
      if (songs.isNotEmpty) {
        context.read<PlayerProvider>().startFmPlaylist(
              songs,
              bufferProvider: _fetchMoreFm,
            );
      }
    } catch (e, s) {
      if (!mounted) return;
      Log.e('WatchFmScreen', 'load error', e, s);
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// 加载更多 FM 推荐（供 PlayerProvider 的 playlistEndProvider 回调使用）
  Future<List<Song>> _fetchMoreFm() async {
    try {
      final player = context.read<PlayerProvider>();
      final playlist = player.playlist;
      final lastSong = playlist.isNotEmpty ? playlist.last : null;
      final musicService = context.read<MusicService>();
      final raw = await musicService.getPersonalFm(
        hash: lastSong?.hash,
        songid: lastSong?.mixSongId ?? lastSong?.id,
        action: 'play',
      );
      return raw
          .map((e) => SongMapper.fromFmJson(e))
          .whereType<Song>()
          .toList();
    } catch (e, s) {
      if (!mounted) return [];
      Log.e('WatchFmScreen', 'fetch more error', e, s);
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  播放操作
  // ═══════════════════════════════════════════════════════════

  /// 切换到下一首（委托给 PlayerProvider，FM 模式下自动续播）
  void _nextTrack() {
    context.read<PlayerProvider>().playNext();
  }

  /// 切换当前歌曲的收藏状态
  void _toggleLike() {
    final song = context.read<PlayerProvider>().currentSong;
    if (song == null) return;
    final likedSongs = context.read<LikedSongsProvider>();
    final songInfo = SongInfo(
      id: song.id,
      name: song.name,
      hash: song.hash ?? '',
      albumId: song.albumId,
      audioId: 0,
    );
    likedSongs.toggle(songInfo);
    HapticFeedback.lightImpact();
  }

  // ═══════════════════════════════════════════════════════════
  //  构建 UI
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _buildErrorOrEmpty();
    }

    // 等待 FM 队列加载到 PlayerProvider
    final player = context.read<PlayerProvider>();
    if (player.playlist.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _buildMainView();
  }

  /// 主界面 — 歌曲信息 + 控制区
  Widget _buildMainView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: RoundSafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              // ── 顶部：私人 FM 标识 ──
              _buildHeader(),

              // ── 中间：歌曲信息 + 播放暂停 ──
              Expanded(
                child: Consumer<PlayerProvider>(
                  builder: (context, player, _) {
                    final song = player.currentSong;
                    if (song == null) {
                      return Center(
                        child: Text(
                          '暂无播放',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      );
                    }
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSongSection(song),
                        const SizedBox(height: 8),
                        _buildPlayButton(player),
                      ],
                    );
                  },
                ),
              ),

              // ── 底部：收藏 + 下一首 ──
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLikeButton(),
                    const SizedBox(width: 24),
                    _buildNextButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部 FM 标识
  Widget _buildHeader() {
    return Text(
      '私人FM',
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSongSection(Song song) {
    return Column(
      key: ValueKey(song.id),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          song.name,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          song.artistDisplay,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    )
    .animate()
    .fadeIn(duration: WatchMotion.durMedium2, curve: WatchMotion.curveDecelerate)
    .slideY(
      begin: 0.1,
      duration: WatchMotion.durMedium2,
      curve: WatchMotion.curveDecelerate,
    );
  }

  Widget _buildPlayButton(PlayerProvider player) {
    return SizedBox(
      width: 48,
      height: 48,
      child: AnimatedSwitcher(
        duration: WatchMotion.durMedium1,
        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
        child: IconButton(
          key: ValueKey(player.isPlaying),
          icon: Icon(
            player.isPlaying
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_filled_rounded,
            size: 40,
          ),
          color: Theme.of(context).colorScheme.primary,
          padding: EdgeInsets.zero,
          onPressed: () {
            WatchMotion.confirm();
            player.togglePlayPause();
          },
          splashRadius: 24,
        ),
      ),
    );
  }

  Widget _buildLikeButton() {
    return Consumer2<PlayerProvider, LikedSongsProvider>(
      builder: (context, player, likedSongs, _) {
        final song = player.currentSong;
        if (song == null) {
          return const SizedBox(width: 40, height: 40);
        }
        final isLiked = likedSongs.likedIds.contains(song.id);
        return SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            icon: Icon(
              isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
              size: 20,
              color: isLiked
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            padding: EdgeInsets.zero,
            splashRadius: 20,
            onPressed: _toggleLike,
          )
          .animate(target: isLiked ? 1 : 0, value: isLiked ? 1 : 0)
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.3, 1.3),
            duration: WatchMotion.durShort4,
            curve: WatchMotion.curveEmphasized,
          ),
        );
      },
    );
  }

  Widget _buildNextButton() {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        icon: const Icon(Icons.skip_next_rounded, size: 24),
        color: Theme.of(context).colorScheme.onSurface,
        padding: EdgeInsets.zero,
        splashRadius: 20,
        onPressed: () {
          WatchMotion.tap();
          _nextTrack();
        },
      ),
    );
  }

  /// 错误 / 空数据占位
  Widget _buildErrorOrEmpty() {
    final theme = Theme.of(context);
    final isError = _error != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.radio_rounded,
                size: 40,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                isError ? '加载失败' : '暂无FM推荐',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              if (isError) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _loadFmSongs,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('重试'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

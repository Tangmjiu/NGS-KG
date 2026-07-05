// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 圆屏私人 FM 电台界面 — 播放/暂停、下一首、收藏

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/song.dart';
import '../../../models/song_mapper.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/liked_songs_provider.dart';
import '../../../services/music_service.dart';
import '../../../utils/logger.dart';
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
  List<Song> _fmSongs = [];
  int _currentIndex = 0;
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
        _fmSongs = songs;
        _currentIndex = 0;
        _isLoading = false;
      });

      // 自动播放第一首
      if (songs.isNotEmpty) {
        _playCurrent();
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

  /// 加载更多 FM 推荐（当列表到达末尾时调用）
  Future<void> _loadMoreFmSongs() async {
    try {
      final lastSong = _fmSongs.isNotEmpty ? _fmSongs.last : null;
      final musicService = context.read<MusicService>();
      final raw = await musicService.getPersonalFm(
        hash: lastSong?.hash,
        songid: lastSong?.mixSongId ?? lastSong?.id,
        action: 'play',
      );
      final songs = raw
          .map((e) => SongMapper.fromFmJson(e))
          .whereType<Song>()
          .toList();

      if (!mounted) return;

      setState(() {
        final prevLen = _fmSongs.length;
        _fmSongs.addAll(songs);
        if (_currentIndex >= prevLen - 1) {
          _currentIndex = prevLen;
        }
      });
    } catch (e, s) {
      if (!mounted) return;
      Log.e('WatchFmScreen', 'load more error', e, s);
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  播放操作
  // ═══════════════════════════════════════════════════════════

  /// 播放当前索引的 FM 歌曲
  void _playCurrent() {
    if (_fmSongs.isEmpty) return;
    final song = _fmSongs[_currentIndex];
    context.read<PlayerProvider>().playSong(song, playlist: _fmSongs);
  }

  /// 切换到下一首
  void _nextTrack() {
    if (_fmSongs.isEmpty) return;

    if (_currentIndex + 1 < _fmSongs.length) {
      setState(() => _currentIndex++);
      _playCurrent();
    } else {
      // 列表耗尽，先加载再切歌
      _loadMoreFmSongs().then((_) {
        if (!mounted) return;
        if (_currentIndex + 1 < _fmSongs.length) {
          setState(() => _currentIndex++);
          _playCurrent();
        }
      });
    }
  }

  /// 切换当前歌曲的收藏状态
  void _toggleLike() {
    if (_fmSongs.isEmpty) return;
    final song = _fmSongs[_currentIndex];
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

    if (_error != null || _fmSongs.isEmpty) {
      return _buildErrorOrEmpty();
    }

    return _buildMainView();
  }

  /// 主界面 — 歌曲信息 + 控制区
  Widget _buildMainView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: RoundSafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // ── 顶部：私人 FM 标识 ──
              _buildHeader(),

              // ── 中间：歌曲信息 + 播放暂停 ──
              Expanded(
                child: Consumer<PlayerProvider>(
                  builder: (context, player, _) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSongSection(),
                        const SizedBox(height: 20),
                        _buildPlayButton(player),
                      ],
                    );
                  },
                ),
              ),

              // ── 底部：收藏 + 下一首 ──
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLikeButton(),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.radio_rounded, size: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        const SizedBox(width: 4),
        Text(
          '私人FM',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  /// 歌曲信息区域：歌名 + 歌手
  Widget _buildSongSection() {
    final song = _fmSongs[_currentIndex];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          song.name,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
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
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// 大型播放 / 暂停按钮（64×64）
  Widget _buildPlayButton(PlayerProvider player) {
    return SizedBox(
      width: 64,
      height: 64,
      child: IconButton(
        icon: Icon(
          player.isPlaying
              ? Icons.pause_circle_filled_rounded
              : Icons.play_circle_filled_rounded,
          size: 56,
        ),
        color: Theme.of(context).colorScheme.primary,
        padding: EdgeInsets.zero,
        onPressed: () => player.togglePlayPause(),
        splashRadius: 32,
      ),
    );
  }

  /// 收藏按钮（心形）
  Widget _buildLikeButton() {
    final song = _fmSongs[_currentIndex];
    return Consumer<LikedSongsProvider>(
      builder: (context, likedSongs, _) {
        final isLiked = likedSongs.likedIds.contains(song.id);
        return SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            icon: Icon(
              isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
              size: 24,
              color: isLiked
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            padding: EdgeInsets.zero,
            splashRadius: 24,
            onPressed: _toggleLike,
          ),
        );
      },
    );
  }

  /// 下一首按钮
  Widget _buildNextButton() {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        icon: const Icon(Icons.skip_next_rounded, size: 28),
        color: Theme.of(context).colorScheme.onSurface,
        padding: EdgeInsets.zero,
        splashRadius: 24,
        onPressed: _nextTrack,
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

// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 手表私人 FM — 封面 + 歌曲信息 + 播放/下一首/收藏

import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:provider/provider.dart';

import '../../../models/song.dart';
import '../../../models/song_mapper.dart';
import '../../../providers/player_provider.dart';
import '../../../services/music_service.dart';
import '../../../utils/logger.dart';
import '../utils/watch_layout.dart';
import '../utils/watch_motion.dart';
import '../widgets/faded_album_art.dart';
import '../widgets/watch_like_button.dart';

/// 手表版私人 FM 电台（外壳 PageView 第 5 页）。
///
/// 加载酷狗私人 FM 推荐并逐首播放；队列播完自动续杯
/// （[PlayerProvider.startFmPlaylist] 的 bufferProvider）。
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

  Future<void> _loadFmSongs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final musicService = context.read<MusicService>();
      final raw = await musicService.getPersonalFm();
      final songs =
          raw.map((e) => SongMapper.fromFmJson(e)).whereType<Song>().toList();
      if (!mounted) return;
      setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_error != null) return _buildError();

    final layout = WatchLayout.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        layout.playerHorizontal,
        layout.topInset,
        layout.playerHorizontal,
        layout.bottomInset,
      ),
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
          final cs = Theme.of(context).colorScheme;
          return Column(
            children: [
              // 顶部标识
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '私人 FM',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // 封面：Flexible 吃掉剩余空间，按可用高度收缩防溢出
              Flexible(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final size =
                        math.min(layout.coverDiameter, c.maxHeight * 0.85);
                    return Center(
                      child: FadedAlbumArt(
                        key: ValueKey(song.id),
                        imageUrl: song.albumCoverUrl,
                        size: size,
                        alpha: 0.9,
                        fadeStart: 0.65,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              // 歌曲信息
              Text(
                song.name,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                song.artistDisplay,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              // 控制行：收藏 / 播放暂停 / 下一首
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  WatchLikeButton(song: song, size: 18),
                  const SizedBox(width: 12),
                  AnimatedSwitcher(
                    duration: WatchMotion.durMedium1,
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Material(
                      key: ValueKey(player.isPlaying),
                      color: cs.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () {
                          WatchMotion.confirm();
                          player.togglePlayPause();
                        },
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: Icon(
                            player.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 28,
                            color: cs.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, size: 24),
                    color: cs.onSurface,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 40, minHeight: 40),
                    onPressed: () {
                      WatchMotion.tap();
                      player.playNext();
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildError() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 36, color: theme.colorScheme.error),
          const SizedBox(height: 8),
          Text('加载失败', style: theme.textTheme.bodyMedium),
          TextButton.icon(
            onPressed: _loadFmSongs,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

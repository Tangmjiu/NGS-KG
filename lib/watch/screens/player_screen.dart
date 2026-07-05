// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 圆屏全屏播放器 — 支持环境模式 (Ambient Mode)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wear_plus/wear_plus.dart';

import '../../../providers/player_provider.dart';
import '../../../providers/liked_songs_provider.dart';
import '../../../models/song.dart';
import '../widgets/round_safe_area.dart';
import 'lyrics_screen.dart';

/// Wear OS 全屏音乐播放器
///
/// 适配圆形屏幕，在 active 模式下显示专辑封面、进度条、控制按钮和收藏按钮；
/// 在 ambient（低功耗）模式下仅显示歌名、歌手和当前时间，黑白配色。
class WatchPlayerScreen extends StatefulWidget {
  const WatchPlayerScreen({super.key});

  @override
  State<WatchPlayerScreen> createState() => _WatchPlayerScreenState();
}

class _WatchPlayerScreenState extends State<WatchPlayerScreen> {
  // ── Ambient 模式下每秒钟更新一次进度文本 ──
  /// Active 模式下 UI 由 PlayerProvider 的 position 驱动，
  /// Ambient 模式下使用局部定时器避免唤醒主线程。

  @override
  void initState() {
    super.initState();
    // Ambient 模式下每秒刷新进度显示
    _startAmbientTimer();
  }

  void _startAmbientTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {});
      _startAmbientTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AmbientMode(
      builder: (context, mode, child) {
        final isAmbient = mode == WearMode.ambient;
        if (isAmbient) {
          return _buildAmbientView();
        }
        return _buildActiveView();
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  //  Ambient Mode — 低功耗单色显示
  // ═══════════════════════════════════════════════════════

  Widget _buildAmbientView() {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        final title = song?.name ?? '';
        final artist = song?.artistDisplay ?? '';
        final timeStr = _formatDuration(player.position);

        return Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 歌名 — 白色
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // 歌手 — 灰色
                  Text(
                    artist,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  // 进度时间 — 灰色
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  //  Active Mode — 全功能播放器
  // ═══════════════════════════════════════════════════════

  Widget _buildActiveView() {
    final isRound = WatchShape.of(context) == WearShape.round;
    final hPad = isRound ? 20.0 : 12.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: RoundSafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 8),
          child: Consumer<PlayerProvider>(
            builder: (context, player, _) {
              final song = player.currentSong;

              if (song == null) {
                return Center(
                  child: Text(
                    '暂无播放',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  // ── Top bar: 返回 + 播放模式 ──
                  _buildTopBar(player),

                  // ── 专辑封面（大圆） ──
                  Expanded(
                    flex: 3,
                    child: _buildAlbumArt(song),
                  ),

                  const SizedBox(height: 4),

                  // ── 歌名 + 歌手 ──
                  _buildSongInfo(song),

                  const SizedBox(height: 4),

                  // ── 进度条 ──
                  _buildProgressBar(player),

                  // ── 控制按钮 ──
                  _buildControls(player),

                  // ── 收藏按钮 ──
                  _buildLikeButton(song),
                ],
              );
            },
        ),
        ),
      ),
    );
  }

  /// 顶部栏：返回按钮 + 歌词/播放模式
  Widget _buildTopBar(PlayerProvider player) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 返回
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
            color: cs.onSurface.withValues(alpha: 0.6),
            onPressed: () => Navigator.pop(context),
          ),
          // 歌词 + 播放模式
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.lyrics_rounded, size: 18),
                color: cs.onSurface.withValues(alpha: 0.6),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WatchLyricsScreen(),
                  ),
                ),
              ),
              _PlayModeIcon(mode: player.playMode),
            ],
          ),
        ],
      ),
    );
  }

  /// 专辑封面：圆形容器 + 渐变色占位 + 音符图标
  Widget _buildAlbumArt(Song song) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 限制最大直径，防止圆屏被裁切
        final maxD = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final diameter = maxD < 140 ? maxD : 140.0;

        return Center(
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.music_note_rounded,
                size: diameter * 0.42,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 歌曲信息：歌名 + 歌手
  Widget _buildSongInfo(Song song) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          song.name,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          song.artistDisplay,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// 进度条：滑块 + 当前位置 / 总时长
  Widget _buildProgressBar(PlayerProvider player) {
    final pos = player.position;
    final dur = player.duration;
    final maxMs = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
    final val = pos.inMilliseconds.toDouble().clamp(0.0, maxMs);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            thumbColor: Theme.of(context).colorScheme.onSurface,
            overlayColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          ),
          child: Slider(
            value: val,
            min: 0,
            max: maxMs,
            onChanged: (v) => player.seek(Duration(milliseconds: v.round())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(pos),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 10),
              ),
              Text(
                _formatDuration(dur),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 控制按钮行：上一首 / 播放暂停 / 下一首
  Widget _buildControls(PlayerProvider player) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 上一首
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, size: 28),
          color: cs.onSurface,
          onPressed: () => player.playPrevious(),
        ),

        const SizedBox(width: 8),

        // 播放/暂停
        IconButton(
          icon: Icon(
            player.isPlaying
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_filled_rounded,
            size: 48,
          ),
          color: cs.primary,
          onPressed: () => player.togglePlayPause(),
        ),
      ],
    );
  }

  /// 收藏按钮（底部）
  Widget _buildLikeButton(Song song) {
    return Consumer<LikedSongsProvider>(
      builder: (context, likedSongs, _) {
        final isLiked = likedSongs.likedIds.contains(song.id);

        return SizedBox(
          height: 28,
          child: Center(
            child: IconButton(
              icon: Icon(
                isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                size: 24,
                color: isLiked
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              splashRadius: 22,
              onPressed: () async {
                final songInfo = SongInfo(
                  id: song.id,
                  name: song.name,
                  hash: song.hash ?? '',
                  albumId: song.albumId,
                  audioId: 0,
                );
                await likedSongs.toggle(songInfo);
                HapticFeedback.lightImpact();
              },
            ),
          ),
        );
      },
    );
  }

  // ── 工具方法 ──

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

// ═══════════════════════════════════════════════════════════
//  播放模式小图标
// ═══════════════════════════════════════════════════════════

class _PlayModeIcon extends StatelessWidget {
  final PlayMode mode;

  const _PlayModeIcon({required this.mode});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String tooltip;

    switch (mode) {
      case PlayMode.shuffle:
        icon = Icons.shuffle_rounded;
        tooltip = '随机播放';
        break;
      case PlayMode.repeatOne:
        icon = Icons.repeat_one_on_rounded;
        tooltip = '单曲循环';
        break;
      case PlayMode.sequential:
      default:
        icon = Icons.repeat_rounded;
        tooltip = '顺序播放';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 20,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
      ),
    );
  }
}

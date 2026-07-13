// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 圆屏全屏播放器 — 支持环境模式 (Ambient Mode)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wear_plus/wear_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../constants/quality.dart';
import '../../../models/song.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/liked_songs_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../utils/login_required_dialog.dart';
import '../utils/watch_motion.dart';
import 'queue_screen.dart';

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
  Timer? _ambientTimer;
  bool _isAmbient = false;

  @override
  void initState() {
    super.initState();
    // 每秒检查：仅在 ambient 模式下 setState 刷新进度显示
    _ambientTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isAmbient) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ambientTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AmbientMode(
      builder: (context, mode, child) {
        _isAmbient = mode == WearMode.ambient;
        if (_isAmbient) {
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
  //  Active Mode — 全功能播放器（重新设计）
  // ═══════════════════════════════════════════════════════

  Widget _buildActiveView() {
    final isRound = WatchShape.of(context) == WearShape.round;
    final hPad = isRound ? 24.0 : 12.0;
    final vPad = isRound ? 6.0 : 8.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // 下滑返回手势
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 800) {
            Navigator.pop(context);
          }
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad),
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

                final hasCover =
                    song.albumCoverUrl != null && song.albumCoverUrl!.isNotEmpty;

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      // ── Top bar: 仅菜单按钮 ──
                      _buildTopBar(player),

                      // ── 专辑封面（仅当有封面 URL 时显示） ──
                      if (hasCover) ...[
                        const SizedBox(height: 4),
                        _buildAlbumArt(song),
                      ],

                      // ── 音质标签 ──
                      const SizedBox(height: 4),
                      _buildQualityLabel(player),

                      // ── 歌名 + 歌手 ──
                      const SizedBox(height: 2),
                      _buildSongInfo(song),

                      const SizedBox(height: 4),

                      // ── 进度条 ──
                      _buildProgressBar(player),

                      const SizedBox(height: 2),

                      // ── 控制按钮 + 收藏 ──
                      _buildControls(player, song),

                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  顶部栏：仅 ⋮ 菜单按钮（返回由下滑手势接管）
  // ═══════════════════════════════════════════════════════

  Widget _buildTopBar(PlayerProvider player) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, size: 20),
            color: cs.onSurface.withValues(alpha: 0.6),
            onPressed: () => _showMenuSheet(player),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  菜单 BottomSheet：播放模式 / 倍速 / 播放队列
  // ═══════════════════════════════════════════════════════

  void _showMenuSheet(PlayerProvider player) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 播放模式切换
                _menuButton(
                  ctx,
                  cs,
                  icon: _playModeIconData(player.playMode),
                  label: _playModeLabel(player.playMode),
                  onTap: () {
                    player.setPlayMode(_nextPlayMode(player.playMode));
                    Navigator.pop(ctx);
                  },
                ),
                // 倍速切换
                _menuButton(
                  ctx,
                  cs,
                  icon: Icons.speed_rounded,
                  label: '${player.currentSpeed.toStringAsFixed(1)}x',
                  onTap: () {
                    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
                    final current = player.currentSpeed;
                    final idx =
                        speeds.indexWhere((s) => (s - current).abs() < 0.01);
                    final next = speeds[(idx + 1) % speeds.length];
                    player.setSpeed(next);
                    Navigator.pop(ctx);
                  },
                ),
                // 播放队列
                _menuButton(
                  ctx,
                  cs,
                  icon: Icons.queue_music_rounded,
                  label: '队列',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WatchQueueScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 菜单按钮 — 竖排图标+标签，适配圆屏 BottomSheet 紧凑空间
  Widget _menuButton(
    BuildContext ctx,
    ColorScheme cs, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: cs.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: cs.onSurface, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _playModeIconData(PlayMode mode) {
    switch (mode) {
      case PlayMode.shuffle:
        return Icons.shuffle_rounded;
      case PlayMode.repeatOne:
        return Icons.repeat_one_on_rounded;
      case PlayMode.sequential:
      default:
        return Icons.repeat_rounded;
    }
  }

  String _playModeLabel(PlayMode mode) {
    switch (mode) {
      case PlayMode.sequential:
        return '顺序播放';
      case PlayMode.shuffle:
        return '随机播放';
      case PlayMode.repeatOne:
        return '单曲循环';
      default:
        return '顺序播放';
    }
  }

  PlayMode _nextPlayMode(PlayMode current) {
    switch (current) {
      case PlayMode.sequential:
        return PlayMode.shuffle;
      case PlayMode.shuffle:
        return PlayMode.repeatOne;
      case PlayMode.repeatOne:
        return PlayMode.sequential;
      default:
        return PlayMode.sequential;
    }
  }

  // ═══════════════════════════════════════════════════════
  //  专辑封面：CachedNetworkImage 圆形容器，最大 120px
  // ═══════════════════════════════════════════════════════

  Widget _buildAlbumArt(Song song) {
    final isRound = WatchShape.of(context) == WearShape.round;
    final diameter = isRound ? 96.0 : 120.0;
    return Center(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: song.albumCoverUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                Container(color: Colors.grey[850]),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[850],
              child: const Icon(
                Icons.music_note_rounded,
                size: 40,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      )
      .animate(key: ValueKey(song.id))
      .fadeIn(duration: WatchMotion.durMedium4, curve: WatchMotion.curveDecelerate)
      .scale(
        begin: const Offset(0.85, 0.85),
        end: const Offset(1.0, 1.0),
        duration: WatchMotion.durMedium4,
        curve: WatchMotion.curveEmphasized,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  音质标签：当前解析到的音质
  // ═══════════════════════════════════════════════════════

  Widget _buildQualityLabel(PlayerProvider player) {
    final qualityKey = player.resolvedQuality ??
        Quality.levels[player.qualityLevel % Quality.levels.length];
    final label = Quality.label(qualityKey);
    return Text(
      '· $label ·',
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        fontSize: 11,
      ),
      textAlign: TextAlign.center,
    );
  }

  // ═══════════════════════════════════════════════════════
  //  歌曲信息：歌名 + 歌手
  // ═══════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════
  //  进度条：滑块（thumb 放大到 14）+ 时间标签
  // ═══════════════════════════════════════════════════════

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
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
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
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
              Text(
                _formatDuration(dur),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  控制按钮行：上一首(28) / 播放暂停(48) / 下一首(28) + 收藏(22)
  // ═══════════════════════════════════════════════════════════

  Widget _buildControls(PlayerProvider player, Song song) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _compactBtn(Icons.skip_previous_rounded, 20, () {
            WatchMotion.tap();
            player.playPrevious();
          }, cs.onSurface),
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: WatchMotion.durMedium1,
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: child,
            ),
            child: IconButton(
              key: ValueKey(player.isPlaying),
              icon: Icon(
                player.isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                size: 36,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              color: cs.primary,
              onPressed: () {
                WatchMotion.confirm();
                player.togglePlayPause();
              },
            ),
          ),
          const SizedBox(width: 4),
          _compactBtn(Icons.skip_next_rounded, 20, () {
            WatchMotion.tap();
            player.playNext();
          }, cs.onSurface),
          const SizedBox(width: 8),
          Consumer<LikedSongsProvider>(
            builder: (context, likedSongs, _) {
              final isLiked = likedSongs.likedIds.contains(song.id);
              return IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                  size: 18,
                  color: isLiked
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                splashRadius: 14,
                onPressed: () async {
                  final auth = context.read<AuthProvider>();
                  if (!auth.isLoggedIn) {
                    final shouldLogin =
                        await showLoginRequiredDialog(context);
                    if (!shouldLogin) return;
                    return;
                  }
                  final songInfo = SongInfo(
                    id: song.id,
                    name: song.name,
                    hash: song.hash ?? '',
                    albumId: song.albumId,
                    audioId: 0,
                  );
                  await likedSongs.toggle(songInfo);
                  WatchMotion.confirm();
                },
              )
              .animate(
                target: isLiked ? 1 : 0,
                value: isLiked ? 1 : 0,
              )
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.3, 1.3),
                duration: WatchMotion.durShort4,
                curve: WatchMotion.curveEmphasized,
              );
            },
          ),
        ],
      ),
      ),
    );
  }

  /// 紧凑型按钮（圆形小屏适配）
  Widget _compactBtn(IconData icon, double size, VoidCallback? onTap, Color color) {
    return IconButton(
      icon: Icon(icon, size: size),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      splashRadius: 16,
      color: color,
      onPressed: onTap,
    );
  }

  // ── 工具方法 ──

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

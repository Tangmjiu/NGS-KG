// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 手表全屏播放器 — 标准化布局
// Flex 列布局：顶部歌名歌手 → 中心圆形封面 → 底部控制+细线进度环
// 角落图标统一偏移，所有数据来自 PlayerProvider 真实状态

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wear_plus/wear_plus.dart';
import 'package:wearable_rotary/wearable_rotary.dart';

import '../../../constants/quality.dart';
import '../../../models/song.dart';
import '../../../providers/player_provider.dart';
import '../utils/format.dart';
import '../utils/watch_layout.dart';
import '../utils/watch_motion.dart';
import '../widgets/faded_album_art.dart';
import '../widgets/partial_arc_progress.dart';
import '../widgets/round_list_tile.dart';
import '../widgets/watch_like_button.dart';
import 'lyrics_screen.dart';
import 'queue_screen.dart';

/// Wear OS 全屏音乐播放器。
///
/// 布局结构（Flex 列，垂直居中）：
/// 1. 顶部：歌名（大）+ 歌手（小），不与封面重叠
/// 2. 中心：圆形封面
/// 3. 底部：三键控制（上一首/播放暂停/下一首）+ 细线进度环环绕
/// 4. 角落图标：左上音质、右上歌词、右下队列，统一偏移量
class WatchPlayerScreen extends StatefulWidget {
  const WatchPlayerScreen({super.key});

  @override
  State<WatchPlayerScreen> createState() => _WatchPlayerScreenState();
}

class _WatchPlayerScreenState extends State<WatchPlayerScreen> {
  bool _isAmbient = false;
  StreamSubscription<RotaryEvent>? _rotarySub;
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _rotarySub = rotaryEvents.listen(_onRotary);
  }

  @override
  void dispose() {
    _rotarySub?.cancel();
    super.dispose();
  }

  void _onRotary(RotaryEvent event) {
    if (!mounted || _isAmbient) return;
    final ticks = event.magnitude != null
        ? (event.magnitude! / 25).clamp(1, 4).round()
        : 1;
    final clockwise = event.direction == RotaryDirection.clockwise;
    setState(() {
      _volume = (_volume + (clockwise ? 0.04 : -0.04) * ticks).clamp(0.0, 1.0);
    });
    context.read<PlayerProvider>().setVolume(_volume);
  }

  @override
  Widget build(BuildContext context) {
    return AmbientMode(
      builder: (context, mode, child) {
        _isAmbient = mode == WearMode.ambient;
        return _isAmbient ? const _AmbientPlayerView() : _buildActiveView();
      },
    );
  }

  Widget _buildActiveView() {
    final layout = WatchLayout.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<PlayerProvider>(
        builder: (context, player, _) {
          final song = player.currentSong;
          if (song == null) return _buildEmpty(context);

          final palette = player.palette;
          final accent = palette?.lightVibrant ??
              palette?.vibrant ??
              palette?.muted ??
              Colors.white;

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTap: () {
              WatchMotion.confirm();
              player.togglePlayPause();
            },
            child: SafeArea(
              minimum: layout.isRound
                  ? EdgeInsets.symmetric(
                      horizontal: layout.diameter * 0.08,
                      vertical: layout.diameter * 0.06,
                    )
                  : const EdgeInsets.all(8),
              child: Stack(
                children: [
                  // ── 主内容：Flex 列布局，垂直居中 ──
                  _PlayerColumn(
                    layout: layout,
                    player: player,
                    song: song,
                    accent: accent,
                    volume: _volume,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
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
}

// ═══════════════════════════════════════════════════════
//  主内容列 — Flex column，垂直居中
// ═══════════════════════════════════════════════════════

class _PlayerColumn extends StatefulWidget {
  final WatchLayout layout;
  final PlayerProvider player;
  final Song song;
  final Color accent;
  final double volume;

  const _PlayerColumn({
    required this.layout,
    required this.player,
    required this.song,
    required this.accent,
    required this.volume,
  });

  @override
  State<_PlayerColumn> createState() => _PlayerColumnState();
}

class _PlayerColumnState extends State<_PlayerColumn> {
  /// 拖动中的本地进度预览（非空时优先显示，松手后清除并 seek）
  double? _dragProgress;

  void _seekTo(double v) {
    final dur = widget.player.duration.inMilliseconds;
    if (dur > 0) {
      widget.player.seek(Duration(milliseconds: (v * dur).round()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    final player = widget.player;
    final song = widget.song;
    final accent = widget.accent;
    final isRound = layout.isRound;
    // 拖动中优先显示本地预览进度（跟手平滑），否则显示真实进度
    final displayProgress = _dragProgress ?? player.progress;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── 1. 顶部行：音质标签(左) | 歌名+歌手(中) | 歌词入口(右) ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _QualityTag(player: player),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      song.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13 * layout.scale,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artistDisplay,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 10 * layout.scale,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            _CornerIcon(
              icon: Icons.lyrics_rounded,
              label: '歌词',
              onTap: () {
                WatchMotion.tap();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WatchLyricsScreen()),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 6),

        // ── 2. 中心封面：圆屏双弧+圆形封面 / 方屏圆角封面+可拖动进度条 ──
        Flexible(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxSide = constraints.maxWidth < constraints.maxHeight
                  ? constraints.maxWidth
                  : constraints.maxHeight;
              if (maxSide < 56) return const SizedBox.shrink();

              if (isRound) {
                // 圆屏：双弧环绕圆形封面
                final ringSize = maxSide;
                final coverSize = (maxSide - 16).clamp(40.0, double.infinity);
                return SizedBox(
                  width: ringSize,
                  height: ringSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 进度弧（可拖动，拖动中加粗提亮，松手 seek）
                      PartialArcProgress(
                        progress: displayProgress,
                        size: ringSize,
                        strokeWidth: 2.5,
                        startAngle: 210,
                        sweep: 120,
                        color: accent.withValues(alpha: 0.35),
                        semanticsLabel: '播放进度',
                        onSeek: (v) => setState(() => _dragProgress = v),
                        onDragStart: () =>
                            setState(() => _dragProgress = player.progress),
                        onDragEnd: () {
                          final v = _dragProgress;
                          if (v != null) _seekTo(v);
                          setState(() => _dragProgress = null);
                        },
                      ),
                      // 音量弧
                      PartialArcProgress(
                        progress: widget.volume,
                        size: ringSize,
                        strokeWidth: 1.5,
                        startAngle: 30,
                        sweep: 120,
                        color: accent.withValues(alpha: 0.15),
                        semanticsLabel: '音量',
                      ),
                      FadedAlbumArt(
                        imageUrl: song.albumCoverUrl,
                        size: coverSize,
                        alpha: 0.85,
                        fadeStart: 0.7,
                      ),
                    ],
                  ),
                );
              }

              // 方屏：圆角封面 + 底部 MD3 可拖动进度条
              final coverSize = (maxSide - 24).clamp(40.0, double.infinity);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(coverSize * 0.12),
                    child: SizedBox(
                      width: coverSize,
                      height: coverSize,
                      child: FadedAlbumArt(
                        imageUrl: song.albumCoverUrl,
                        size: coverSize,
                        alpha: 0.95,
                        fadeStart: 0.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: constraints.maxWidth * 0.85,
                    child: Slider(
                      value: displayProgress.clamp(0.0, 1.0),
                      onChanged: (v) => setState(() => _dragProgress = v),
                      onChangeEnd: (v) {
                        _seekTo(v);
                        setState(() => _dragProgress = null);
                      },
                      activeColor: accent,
                      inactiveColor: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 6),

        // ── 3. 底部行：收藏(左) | 控制按钮(中) | 队列(右) ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            WatchLikeButton(song: song, size: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${formatWatchDuration(player.position)} / ${formatWatchDuration(player.duration)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 9 * layout.scale,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  _ControlRow(
                    player: player,
                    song: song,
                    accent: accent,
                    layout: layout,
                  ),
                  const SizedBox(height: 4),
                  _CurrentLyricLine(player: player),
                ],
              ),
            ),
            _CornerIcon(
              icon: Icons.queue_music_rounded,
              label: '队列',
              onTap: () {
                WatchMotion.tap();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WatchQueueScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

// //  控制按钮行 — 透明底，横向排列
// ═══════════════════════════════════════════════════════

class _ControlRow extends StatelessWidget {
  final PlayerProvider player;
  final Song song;
  final Color accent;
  final WatchLayout layout;

  const _ControlRow({
    required this.player,
    required this.song,
    required this.accent,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CircleBtn(
            icon: Icons.skip_previous_rounded,
            label: '上一首',
            size: 26 * layout.scale,
            onTap: player.playPrevious,
          ),
          const SizedBox(width: 14),
          _CircleBtn(
            icon: player.isPlaying
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            label: player.isPlaying ? '暂停' : '播放',
            size: 36 * layout.scale,
            accent: accent,
            onTap: () {
              WatchMotion.confirm();
              player.togglePlayPause();
            },
          ),
          const SizedBox(width: 14),
          _CircleBtn(
            icon: Icons.skip_next_rounded,
            label: '下一首',
            size: 26 * layout.scale,
            onTap: player.playNext,
          ),
        ],
      ),
    );
  }
}

/// 圆形透明按钮（白色图标 + 阴影保证可读性，触摸目标 >= 48dp）。
class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final double size;
  final VoidCallback onTap;
  final Color? accent;

  const _CircleBtn({
    required this.icon,
    required this.label,
    required this.size,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () {
          WatchMotion.tap();
          onTap();
        },
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: size,
            color: accent ?? Colors.white,
            shadows: const [
              Shadow(color: Colors.black87, blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  当前歌词行（动画切换）
// ═══════════════════════════════════════════════════════

class _CurrentLyricLine extends StatefulWidget {
  final PlayerProvider player;

  const _CurrentLyricLine({required this.player});

  @override
  State<_CurrentLyricLine> createState() => _CurrentLyricLineState();
}

class _CurrentLyricLineState extends State<_CurrentLyricLine> {
  String? _line;
  int _lastIdx = -1;

  @override
  void initState() {
    super.initState();
    widget.player.lyricController.activeIndexNotifiter.addListener(_onLyric);
    _onLyric();
  }

  @override
  void dispose() {
    widget.player.lyricController.activeIndexNotifiter.removeListener(_onLyric);
    super.dispose();
  }

  void _onLyric() {
    final idx = widget.player.lyricController.activeIndexNotifiter.value;
    if (idx == _lastIdx) return;
    _lastIdx = idx;
    final model = widget.player.lyricController.lyricNotifier.value;
    if (model != null && idx >= 0 && idx < model.lines.length) {
      final text = model.lines[idx].text;
      if (mounted) setState(() => _line = text);
    } else {
      if (mounted) setState(() => _line = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_line == null || _line!.isEmpty) return const SizedBox.shrink();
    return AnimatedSwitcher(
      duration: WatchMotion.durMedium1,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Text(
        _line!,
        key: ValueKey(_line),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  角落图标 — 统一样式
// ═══════════════════════════════════════════════════════

class _CornerIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CornerIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () {
          WatchMotion.tap();
          onTap();
        },
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 16,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

/// 音质标签（左上角）。
class _QualityTag extends StatelessWidget {
  final PlayerProvider player;
  const _QualityTag({required this.player});

  @override
  Widget build(BuildContext context) {
    final qualityKey = player.resolvedQuality ??
        Quality.levels[player.qualityLevel % Quality.levels.length];
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        Quality.label(qualityKey),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  播放菜单页
// ═══════════════════════════════════════════════════════

// ignore: unused_element
class _PlayerMenuScreen extends StatelessWidget {
  final PlayerProvider player;
  const _PlayerMenuScreen({required this.player});

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          layout.listHorizontal,
          layout.topInset + 8,
          layout.listHorizontal,
          layout.bottomInset + 16,
        ),
        children: [
          Consumer<PlayerProvider>(
            builder: (context, p, _) => RoundListTile(
              title: '播放模式',
              subtitle: _modeLabel(p.playMode),
              leading: Icon(_modeIcon(p.playMode)),
              onTap: () => p.setPlayMode(_nextMode(p.playMode)),
            ),
          ),
          Consumer<PlayerProvider>(
            builder: (context, p, _) => RoundListTile(
              title: '倍速',
              subtitle: '${p.currentSpeed.toStringAsFixed(2)}x',
              leading: const Icon(Icons.speed_rounded),
              onTap: () {
                const speeds = [1.0, 0.5, 0.75, 1.25, 1.5, 2.0];
                final idx =
                    speeds.indexWhere((s) => (s - p.currentSpeed).abs() < 0.01);
                p.setSpeed(speeds[(idx + 1) % speeds.length]);
              },
            ),
          ),
          RoundListTile(
            title: '播放队列',
            subtitle: '${player.playlist.length} 首',
            leading: const Icon(Icons.queue_music_rounded),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WatchQueueScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  static IconData _modeIcon(PlayMode mode) => switch (mode) {
        PlayMode.shuffle => Icons.shuffle_rounded,
        PlayMode.repeatOne => Icons.repeat_one_rounded,
        _ => Icons.repeat_rounded,
      };

  static String _modeLabel(PlayMode mode) => switch (mode) {
        PlayMode.shuffle => '随机播放',
        PlayMode.repeatOne => '单曲循环',
        PlayMode.radio => '电台模式',
        _ => '顺序播放',
      };

  static PlayMode _nextMode(PlayMode mode) => switch (mode) {
        PlayMode.sequential => PlayMode.shuffle,
        PlayMode.shuffle => PlayMode.repeatOne,
        _ => PlayMode.sequential,
      };
}

// ═══════════════════════════════════════════════════════
//  Ambient Mode
// ═══════════════════════════════════════════════════════

class _AmbientPlayerView extends StatefulWidget {
  const _AmbientPlayerView();

  @override
  State<_AmbientPlayerView> createState() => _AmbientPlayerViewState();
}

class _AmbientPlayerViewState extends State<_AmbientPlayerView> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  void _scheduleTick() {
    final now = DateTime.now();
    _timer = Timer(
      Duration(seconds: 60 - now.second, milliseconds: -now.millisecond),
      () {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
        _scheduleTick();
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    final timeStr =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        final accent = player.palette?.lightVibrant ??
            player.palette?.vibrant ??
            Colors.white38;
        return Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(layout.diameter * 0.16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: LinearProgressIndicator(
                      value: player.progress.clamp(0.0, 1.0),
                      minHeight: 2,
                      color: accent.withValues(alpha: 0.4),
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song?.name ?? '',
                    style: TextStyle(
                      color: accent.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Icon(
                    player.isPlaying
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    color: Colors.white38,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

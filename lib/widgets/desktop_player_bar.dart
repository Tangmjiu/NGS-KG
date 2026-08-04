// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/player_provider.dart';
import '../providers/liked_songs_provider.dart';
import '../models/song.dart';
import '../utils/theme.dart';
import '../screens/player_screen.dart';
import '../utils/navigation.dart' as app;
import 'playback_controls.dart';

/// 桌面端播放栏 (Music You 风格):
/// 68px 高, 进度条悬浮上边缘, 三栏 1:1:1 布局,
/// 播放键为 primaryContainer 圆钮, 播放时形变为圆角矩形。
class DesktopPlayerBar extends StatefulWidget {
  const DesktopPlayerBar({super.key});

  @override
  State<DesktopPlayerBar> createState() => _DesktopPlayerBarState();
}

class _DesktopPlayerBarState extends State<DesktopPlayerBar> {
  bool _isHoveringCover = false;

  @override
  Widget build(BuildContext context) {
    // 精确订阅: 只监听低频状态, 避免进度 tick 导致整条播放条重建
    final song = context.select<PlayerProvider, Song?>((p) => p.currentSong);
    if (song == null) return const SizedBox.shrink();
    final isPlaying = context.select<PlayerProvider, bool>((p) => p.isPlaying);
    final isLoading = context.select<PlayerProvider, bool>((p) => p.isLoading);
    final playMode = context.select<PlayerProvider, PlayMode>((p) => p.playMode);

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Positioned(
      left: 32,
      right: 32,
      bottom: 24,
      height: 72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // ── 置底边缘的交互式进度条 ──
              Positioned(
                bottom: -8,
                left: 0,
                right: 0,
                child: _InteractiveProgressBar(cs: cs),
              ),

          // ── 三栏内容排版 (1:1:1) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // 1. 左侧:歌曲封面、信息、喜欢按钮
                Expanded(
                  child: Row(
                    children: [
                      MouseRegion(
                        onEnter: (_) =>
                            setState(() => _isHoveringCover = true),
                        onExit: (_) =>
                            setState(() => _isHoveringCover = false),
                        child: GestureDetector(
                          onTap: () => _openPlayerScreen(context),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Hero(
                                tag: 'album_art_${song.hash ?? song.id}',
                                child: _buildCoverArt(song, cs, isLoading),
                              ),
                              if (_isHoveringCover)
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    borderRadius: AppShape.sm,
                                  ),
                                  child: const Icon(
                                    Icons.open_in_full_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artistDisplay,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 喜欢按钮
                      Consumer<LikedSongsProvider>(
                        builder: (_, lp, __) {
                          final liked = lp.likedIds.contains(song.id);
                          return M3BounceFeedback(
                            trigger: liked,
                            child: IconButton(
                              icon: Icon(
                                liked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 20,
                              ),
                              color: liked ? cs.error : cs.onSurfaceVariant,
                              tooltip: liked ? '取消喜欢' : '喜欢',
                              onPressed: () {
                                lp.toggle(SongInfo(
                                  id: song.id,
                                  name: song.name,
                                  hash: song.hash ?? '',
                                  albumId: song.albumId,
                                  audioId: song.id,
                                ));
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // 2. 中间:播放控制器
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 播放模式
                      _buildModeButton(playMode, cs),
                      const SizedBox(width: 4),
                      // 上一首
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded,
                            size: 24),
                        color: cs.onSurface,
                        onPressed: context
                            .read<PlayerProvider>()
                            .playPrevious,
                      ),
                      const SizedBox(width: 8),
                      // 播放/暂停 (圆形 ↔ 圆角矩形形变)
                      _buildPlayPauseButton(isPlaying, isLoading, cs),
                      const SizedBox(width: 8),
                      // 下一首
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded, size: 24),
                        color: cs.onSurface,
                        onPressed:
                            context.read<PlayerProvider>().playNext,
                      ),
                      const SizedBox(width: 4),
                      // 时间显示 (独立订阅, 避免整条重建)
                      const _TimeText(),
                    ],
                  ),
                ),

                // 3. 右侧:歌词、队列与音量
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 歌词页切换
                      IconButton(
                        icon: const Icon(Icons.lyrics_outlined, size: 20),
                        color: cs.onSurfaceVariant,
                        tooltip: '歌词面板',
                        onPressed: () => _openPlayerScreen(context),
                      ),
                      // 播放队列
                      IconButton(
                        icon: const Icon(Icons.queue_music_rounded, size: 20),
                        color: cs.onSurfaceVariant,
                        tooltip: '播放队列',
                        onPressed: () => PlaybackControls.showPlaylistStatic(
                            context,
                            context.read<PlayerProvider>()),
                      ),
                      const SizedBox(width: 8),
                      // 音量控制组 (独立订阅 volume)
                      const _VolumeSlider(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
          ), // Stack
        ), // Container
      ), // ClipRRect
    ); // Positioned
  }

  Widget _buildCoverArt(Song song, ColorScheme cs, bool isLoading) {
    Widget coverWidget;
    final url = song.thumbnailCoverUrl;
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('file:') || url.startsWith('/')) {
        final path =
            url.startsWith('file:') ? Uri.parse(url).toFilePath() : url;
        final file = File(path);
        if (file.existsSync()) {
          coverWidget =
              Image.file(file, width: 52, height: 52, fit: BoxFit.cover);
        } else {
          coverWidget = _defaultCoverIcon(cs);
        }
      } else {
        coverWidget = CachedNetworkImage(
          imageUrl: url,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          memCacheWidth: 104,
          memCacheHeight: 104,
          errorWidget: (_, __, ___) => _defaultCoverIcon(cs),
        );
      }
    } else {
      coverWidget = _defaultCoverIcon(cs);
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: AppShape.sm,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppShape.sm,
        child: Stack(
          alignment: Alignment.center,
          children: [
            coverWidget,
            if (isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _defaultCoverIcon(ColorScheme cs) {
    return Container(
      width: 52,
      height: 52,
      color: cs.surfaceContainerHigh,
      child: Icon(Icons.music_note_rounded, size: 24, color: cs.primary),
    );
  }

  /// 播放/暂停键: primaryContainer 圆钮, 播放时形变为圆角矩形 (Material You 动效)
  Widget _buildPlayPauseButton(
      bool isPlaying, bool isLoading, ColorScheme cs) {
    return AnimatedContainer(
      duration: AppMotion.dMedium1,
      curve: AppMotion.emphasized,
      width: isPlaying ? 50 : 44,
      height: 44,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(isPlaying ? 14 : 22),
        boxShadow: [
          BoxShadow(
            color: cs.primaryContainer.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(isPlaying ? 14 : 22),
        onTap: () => context.read<PlayerProvider>().togglePlayPause,
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: cs.primary),
                )
              : AnimatedSwitcher(
                  duration: AppMotion.dShort4,
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    key: ValueKey<bool>(isPlaying),
                    color: cs.onPrimaryContainer,
                    size: 26,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildModeButton(PlayMode playMode, ColorScheme cs) {
    IconData icon;
    String label;
    switch (playMode) {
      case PlayMode.shuffle:
        icon = Icons.shuffle_rounded;
        label = '随机播放';
        break;
      case PlayMode.repeatOne:
        icon = Icons.repeat_one_rounded;
        label = '单曲循环';
        break;
      case PlayMode.sequential:
      default:
        icon = Icons.repeat_rounded;
        label = '顺序播放';
        break;
    }

    return IconButton(
      icon: Icon(icon, size: 18),
      color: playMode == PlayMode.sequential
          ? cs.onSurfaceVariant
          : cs.primary,
      tooltip: label,
      onPressed: () {
        final player = context.read<PlayerProvider>();
        const modes = [
          PlayMode.sequential,
          PlayMode.shuffle,
          PlayMode.repeatOne
        ];
        final next = modes[(modes.indexOf(player.playMode) + 1) % modes.length];
        player.setPlayMode(next);
      },
    );
  }

  void _openPlayerScreen(BuildContext context) {
    final player = context.read<PlayerProvider>();
    player.setPlayerScreenVisible(true);
  }
}

/// 贴置顶边缘的交互进度条 (独立订阅 position/duration, 不重建整条播放条)
class _InteractiveProgressBar extends StatelessWidget {
  final ColorScheme cs;

  const _InteractiveProgressBar({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerProvider, ({Duration position, Duration duration})>(
      selector: (_, p) => (position: p.position, duration: p.duration),
      builder: (context, state, _) {
        final player = context.read<PlayerProvider>();
        final durationMs = state.duration.inMilliseconds;
        final positionMs = state.position.inMilliseconds;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: 20,
            alignment: Alignment.center,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                trackShape: const RectangularSliderTrackShape(),
                thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 0, disabledThumbRadius: 0),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: cs.primary,
                inactiveTrackColor: cs.outlineVariant.withValues(alpha: 0.15),
              ),
              child: Slider(
                value: positionMs.toDouble().clamp(
                    0, durationMs.toDouble() > 0 ? durationMs.toDouble() : 1.0),
                min: 0,
                max: durationMs.toDouble() > 0 ? durationMs.toDouble() : 1.0,
                onChanged: (val) {
                  player.seek(Duration(milliseconds: val.toInt()));
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 播放时间文本 (独立订阅 position/duration)
class _TimeText extends StatelessWidget {
  const _TimeText();

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerProvider, ({Duration position, Duration duration})>(
      selector: (_, p) => (position: p.position, duration: p.duration),
      builder: (context, state, _) {
        final cs = Theme.of(context).colorScheme;
        return Text(
          '${_formatDuration(state.position)} / ${_formatDuration(state.duration)}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
        );
      },
    );
  }
}

/// 音量滑块控制组 (独立订阅 volume)
class _VolumeSlider extends StatefulWidget {
  const _VolumeSlider();

  @override
  State<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  double _lastVolume = 1.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final volume = context.select<PlayerProvider, double>((p) => p.volume);
    final isMuted = volume == 0;

    IconData volIcon = Icons.volume_up_rounded;
    if (isMuted) {
      volIcon = Icons.volume_off_rounded;
    } else if (volume < 0.3) {
      volIcon = Icons.volume_mute_rounded;
    } else if (volume < 0.7) {
      volIcon = Icons.volume_down_rounded;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(volIcon, size: 20),
          color: cs.onSurfaceVariant,
          onPressed: () {
            final player = context.read<PlayerProvider>();
            if (isMuted) {
              player.setVolume(_lastVolume);
            } else {
              _lastVolume = volume > 0 ? volume : 1.0;
              player.setVolume(0.0);
            }
          },
        ),
        SizedBox(
          width: 90,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
              activeTrackColor: cs.primary,
              inactiveTrackColor: cs.outlineVariant.withValues(alpha: 0.3),
              thumbColor: cs.primary,
            ),
            child: Slider(
              value: volume,
              min: 0.0,
              max: 1.0,
              onChanged: (val) {
                context.read<PlayerProvider>().setVolume(val);
              },
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:io';

import 'package:adaptive_palette/adaptive_palette.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/player_provider.dart';
import '../providers/liked_songs_provider.dart';
import '../providers/theme_provider.dart';
import '../models/song.dart';
import '../utils/theme.dart';
import 'desktop_amll_lyrics_view.dart';
import 'hi_res_badge.dart';
import 'lyric_settings_panel.dart';
import 'playback_controls.dart';
import 'player_extras_panel.dart';

/// 桌面全屏播放器 —— 纯 Flutter 实现（替代原 AMLL WebView）。
///
/// - 背景: adaptive_palette `FluidBackground`（本地 fork：旋转改为连续
///   正弦摆动，消除 12s 循环边界跳变）
/// - 布局: Apple Music 风格 —— 左侧大封面 + 右侧歌词 (自研 AMLL 风格视图，
///   见 [DesktopAmllLyricsView]，保留间奏动画/滚轮浏览，不依赖 amlv/WebView)
/// - 控制: 底部悬浮控制条（Dart 层, 不依赖 WebView）
class DesktopFullscreenPlayer extends StatefulWidget {
  final VoidCallback onClose;
  const DesktopFullscreenPlayer({super.key, required this.onClose});

  @override
  State<DesktopFullscreenPlayer> createState() =>
      _DesktopFullscreenPlayerState();
}

class _DesktopFullscreenPlayerState extends State<DesktopFullscreenPlayer> {
  double? _dragPosMs;

  @override
  Widget build(BuildContext context) {
    // select 只订阅封面变化, position 高频通知不会重建背景层
    final coverUrl = context.select<PlayerProvider, String?>(
        (p) => p.currentSong?.thumbnailCoverUrl);
    // 跟随"动态流光"开关（与 Android 分支 PlayerBackground 行为一致）
    final flowEnabled = context.watch<ThemeProvider>().flowLightEnabled;

    return FluidBackground(
      imageProvider: coverUrl != null && coverUrl.isNotEmpty
          ? NetworkImage(coverUrl)
          : null,
      blurSigma: 80,
      overlayDarken: 0.14,
      animate: flowEnabled,
      fallbackMode: FluidFallbackMode.dark,
      child: Stack(
        children: [
          // 主内容区: 左侧大封面 + 右侧歌词 (Apple Music 布局)
          Positioned(
            top: 88,
            left: 48,
            right: 48,
            bottom: 148,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 24.0, horizontal: 32.0),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _buildCoverPanel(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 48),
                Expanded(
                  flex: 6,
                  child: _buildLyricsArea(),
                ),
              ],
            ),
          ),
          // 顶部返回按钮
          Positioned(
            top: 40,
            left: 40,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 36),
              color: Colors.white70,
              onPressed: widget.onClose,
            ),
          ),
          // 底部控制条
          Positioned(
            left: 32,
            right: 32,
            bottom: 24,
            child: _buildControlBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Consumer<PlayerProvider>(
            builder: (context, player, _) {
              if (player.lyricLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white54),
                );
              }
              final hasLyrics = player
                      .lyricController.lyricNotifier.value?.lines.isNotEmpty ??
                  false;
              if (!hasLyrics) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lyrics_outlined,
                          size: 56, color: Colors.white24),
                      const SizedBox(height: 12),
                      Text(
                        '暂无歌词',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.38),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const DesktopAmllLyricsView();
            },
          ),
        ),
        const SizedBox(height: 16),
        _buildLyricsToolbar(),
      ],
    );
  }

  /// 歌词工具条: 来源徽章(点击歌词设置) + 翻译/罗马音开关。
  Widget _buildLyricsToolbar() {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final hasLang = player.hasLangData;
        final hasRoma = player.hasRomajiData;
        return Row(
          children: [
            GestureDetector(
              onTap: _showLyricSettings,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('词',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    SizedBox(width: 4),
                    Text('KUGOU',
                        style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (hasLang) ...[
              _toggleChip(
                label: '翻译',
                active: player.showTranslation,
                onTap: player.toggleTranslation,
              ),
              const SizedBox(width: 8),
            ],
            if (hasRoma) ...[
              _toggleChip(
                label: '罗马音',
                active: player.showRomaji,
                onTap: player.toggleRomaji,
              ),
              const SizedBox(width: 8),
            ],
            IconButton(
              tooltip: '歌词设置',
              icon: const Icon(Icons.settings_outlined, size: 18),
              color: Colors.white54,
              onPressed: _showLyricSettings,
            ),
          ],
        );
      },
    );
  }

  Widget _toggleChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: active ? 0.18 : 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: active ? 0.38 : 0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: active ? 0.95 : 0.5),
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _showLyricSettings() {
    showM3Dialog(
      context: context,
      // root Navigator：桌面端自建 Shell Navigator 的弹窗层不可靠
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          '歌词设置',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: const SizedBox(width: 360, child: LyricSettingsPanel()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('完成', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// 左侧封面面板: 大封面 + 歌名/歌手/音质。
  Widget _buildCoverPanel() {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.music_note_rounded,
                    size: 56, color: Colors.white24),
                const SizedBox(height: 12),
                Text(
                  '暂无播放',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.38),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }
        // Hi-Res 金标：真实源解析为 Hi-Res 且设置开启时显示
        // （在 build 流程内订阅，不能放到 State 方法里 select）
        final showHiRes =
            context.select<PlayerProvider, String?>((p) => p.resolvedQuality) ==
                    'high' &&
                context.select<ThemeProvider, bool>((tp) => tp.showHiResBadge);
        // 左侧只放封面（直角大封面），歌曲信息在底部控制条里已有
        return Center(
          child: _buildLargeCover(song, player.isPlaying, showHiRes),
        );
      },
    );
  }

  /// 大封面：播放/暂停弹性变焦 + Hi-Res 金标（与 Android 分支一致）
  Widget _buildLargeCover(Song song, bool isPlaying, bool showHiRes) {
    final cover = _largeCoverImage(song);
    return AnimatedScale(
      // 播放时展开至 1.0，暂停时收缩至 0.88（弹性变焦）
      scale: isPlaying ? 1.0 : 0.88,
      duration: AppMotion.dMedium4,
      curve: AppMotion.emphasizedDecelerate,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 48,
              spreadRadius: 4,
              offset: const Offset(0, 24),
            ),
          ],
        ),
        // 直角封面（Apple Music 桌面端风格）
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            cover,
            if (showHiRes)
              const Positioned(
                left: 8,
                bottom: 12,
                child: HiResBadge(height: 32),
              ),
          ],
        ),
      ),
    );
  }

  Widget _largeCoverImage(Song song) {
    final data = song.coverData;
    if (data != null && data.isNotEmpty) {
      return Image.memory(data, fit: BoxFit.cover);
    }
    var url = song.albumCoverUrl;
    if (url == null || url.isEmpty) return _defaultCover();
    if (url.contains('{size}')) url = url.replaceAll('{size}', '480');
    if (url.startsWith('file://') || url.startsWith('/')) {
      final path =
          url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultCover(),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 480,
      memCacheHeight: 480,
      errorWidget: (_, __, ___) => _defaultCover(),
    );
  }

  Widget _defaultCover() {
    return Container(
      color: Colors.white.withValues(alpha: 0.12),
      child: const Center(
        child: Icon(Icons.music_note_rounded, size: 64, color: Colors.white38),
      ),
    );
  }

  Widget _buildControlBar() {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) {
          // 队列为空：显示空状态（避免整条控制条空白）
          return Container(
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(38),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Text(
              '暂无播放',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          );
        }

        final durationMs = player.duration.inMilliseconds.toDouble();
        final posMs = (_dragPosMs ?? player.position.inMilliseconds.toDouble())
            .clamp(0.0, durationMs > 0 ? durationMs : 0.0);
        final isPlaying = player.isPlaying;
        final isLoading = player.isLoading;
        final playMode = player.playMode;

        return Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(38),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // 封面 + 歌曲信息
              _buildCover(song),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      song.artistDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 播放模式
              IconButton(
                icon: Icon(_modeIcon(playMode), size: 20),
                color: playMode == PlayMode.sequential
                    ? Colors.white54
                    : Colors.white,
                tooltip: _modeLabel(playMode),
                onPressed: () {
                  const modes = [
                    PlayMode.sequential,
                    PlayMode.shuffle,
                    PlayMode.repeatOne,
                  ];
                  final next =
                      modes[(modes.indexOf(playMode) + 1) % modes.length];
                  player.setPlayMode(next);
                },
              ),
              const SizedBox(width: 4),
              // 上一首
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, size: 28),
                color: Colors.white,
                onPressed: player.playPrevious,
              ),
              const SizedBox(width: 8),
              // 播放/暂停
              _buildPlayPauseButton(isPlaying, isLoading),
              const SizedBox(width: 8),
              // 下一首
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, size: 28),
                color: Colors.white,
                onPressed: player.playNext,
              ),
              const SizedBox(width: 8),
              // 喜欢
              Consumer<LikedSongsProvider>(
                builder: (context, lp, _) {
                  final liked = lp.likedIds.contains(song.id);
                  return IconButton(
                    icon: Icon(
                      liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 22,
                    ),
                    color: liked ? const Color(0xFFF44336) : Colors.white54,
                    tooltip: liked ? '取消喜欢' : '喜欢',
                    onPressed: () => lp.toggle(SongInfo(
                      id: song.id,
                      name: song.name,
                      hash: song.hash ?? '',
                      albumId: song.albumId,
                      audioId: song.id,
                    )),
                  );
                },
              ),
              // 进度 + 时间
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Text(
                      _fmt(posMs ~/ 1000),
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          activeTrackColor: Colors.white,
                          inactiveTrackColor:
                              Colors.white.withValues(alpha: 0.2),
                          thumbColor: Colors.white,
                          overlayColor: Colors.white.withValues(alpha: 0.12),
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                        ),
                        child: Slider(
                          value: posMs,
                          max: durationMs > 0 ? durationMs : 1,
                          onChangeStart: (v) => setState(() => _dragPosMs = v),
                          onChanged: (v) => setState(() => _dragPosMs = v),
                          onChangeEnd: (v) {
                            setState(() => _dragPosMs = null);
                            player.seek(Duration(milliseconds: v.round()));
                          },
                        ),
                      ),
                    ),
                    Text(
                      _fmt(durationMs ~/ 1000),
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // 播放队列
              IconButton(
                icon: const Icon(Icons.queue_music_rounded, size: 20),
                color: Colors.white54,
                tooltip: '播放队列',
                onPressed: () =>
                    PlaybackControls.showPlaylistStatic(context, player),
              ),
              // 音量（hover 展开滑块，Apple Music 全屏风格）
              const _FullscreenVolumeControl(),
              // 更多：倍速 / 音质 / 音效 / 定时关闭
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded, size: 20),
                color: Colors.white54,
                tooltip: '播放选项',
                onPressed: () => PlayerExtrasPanel.show(context),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _modeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.shuffle:
        return Icons.shuffle_rounded;
      case PlayMode.repeatOne:
        return Icons.repeat_one_rounded;
      case PlayMode.sequential:
      default:
        return Icons.repeat_rounded;
    }
  }

  String _modeLabel(PlayMode mode) {
    switch (mode) {
      case PlayMode.shuffle:
        return '随机播放';
      case PlayMode.repeatOne:
        return '单曲循环';
      case PlayMode.sequential:
      default:
        return '顺序播放';
    }
  }

  Widget _buildCover(Song song) {
    Widget cover;
    final url = song.thumbnailCoverUrl;
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('file:') || url.startsWith('/')) {
        final path =
            url.startsWith('file:') ? Uri.parse(url).toFilePath() : url;
        final file = File(path);
        if (file.existsSync()) {
          cover = Image.file(
            file,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _defaultCoverIcon(),
          );
        } else {
          cover = _defaultCoverIcon();
        }
      } else {
        cover = CachedNetworkImage(
          imageUrl: url,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          memCacheWidth: 104,
          memCacheHeight: 104,
          errorWidget: (_, __, ___) => _defaultCoverIcon(),
        );
      }
    } else {
      cover = _defaultCoverIcon();
    }
    return Container(
      width: 52,
      height: 52,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: AppShape.sm,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: cover,
    );
  }

  Widget _defaultCoverIcon() {
    return Container(
      color: Colors.white.withValues(alpha: 0.12),
      child:
          const Icon(Icons.music_note_rounded, size: 26, color: Colors.white70),
    );
  }

  Widget _buildPlayPauseButton(bool isPlaying, bool isLoading) {
    return AnimatedContainer(
      duration: AppMotion.dMedium1,
      curve: AppMotion.emphasized,
      width: isPlaying ? 52 : 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isPlaying ? 15 : 23),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(isPlaying ? 15 : 23),
        onTap: () => context.read<PlayerProvider>().togglePlayPause(),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black87),
                )
              : AnimatedSwitcher(
                  duration: AppMotion.dShort4,
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    key: ValueKey<bool>(isPlaying),
                    color: Colors.black87,
                    size: 28,
                  ),
                ),
        ),
      ),
    );
  }

  String _fmt(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// 全屏控制条音量控件：默认仅音量图标（点击切换静音），
/// 鼠标 hover 时展开 84px 滑块（Apple Music 全屏风格，节省常驻空间）。
class _FullscreenVolumeControl extends StatefulWidget {
  const _FullscreenVolumeControl();

  @override
  State<_FullscreenVolumeControl> createState() =>
      _FullscreenVolumeControlState();
}

class _FullscreenVolumeControlState extends State<_FullscreenVolumeControl> {
  bool _hovering = false;
  double _lastVolume = 1.0;

  @override
  Widget build(BuildContext context) {
    // 独立订阅 volume，避免高频 position 通知重建
    final volume = context.select<PlayerProvider, double>((p) => p.volume);
    final isMuted = volume == 0;

    IconData icon = Icons.volume_up_rounded;
    if (isMuted) {
      icon = Icons.volume_off_rounded;
    } else if (volume < 0.3) {
      icon = Icons.volume_mute_rounded;
    } else if (volume < 0.7) {
      icon = Icons.volume_down_rounded;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(icon, size: 20),
            color: Colors.white54,
            tooltip: isMuted ? '取消静音' : '静音',
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
          ClipRect(
            child: AnimatedContainer(
              duration: AppMotion.dShort4,
              curve: AppMotion.emphasized,
              width: _hovering ? 84 : 0,
              height: 40,
              alignment: Alignment.centerLeft,
              child: _hovering
                  ? SizedBox(
                      width: 84,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          activeTrackColor: Colors.white,
                          inactiveTrackColor:
                              Colors.white.withValues(alpha: 0.2),
                          thumbColor: Colors.white,
                          overlayColor: Colors.white.withValues(alpha: 0.12),
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5),
                        ),
                        child: Slider(
                          value: volume,
                          min: 0.0,
                          max: 1.0,
                          onChanged: (v) =>
                              context.read<PlayerProvider>().setVolume(v),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

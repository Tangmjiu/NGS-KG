import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/player_provider.dart';
import '../providers/liked_songs_provider.dart';
import '../models/song.dart';
import '../utils/local_server.dart';
import '../utils/ttml_generator.dart';
import '../utils/theme.dart';
import '../services/amll_webview_manager.dart';

class DesktopFullscreenPlayer extends StatefulWidget {
  final VoidCallback onClose;
  const DesktopFullscreenPlayer({super.key, required this.onClose});

  @override
  State<DesktopFullscreenPlayer> createState() => _DesktopFullscreenPlayerState();
}

class _DesktopFullscreenPlayerState extends State<DesktopFullscreenPlayer> {
  WebviewController get _controller => AmllWebviewManager.instance.controller;
  late final PlayerProvider _player;

  int? _lastSongId;
  bool _lastIsPlaying = false;
  int _lastTimeSentMs = -1;
  double? _dragPosMs;
  String? _lastLyricFp;

  @override
  void initState() {
    super.initState();
    _player = context.read<PlayerProvider>();
    // Webview 已由 AmllWebviewManager 常驻预加载; 打开时立即全量同步当前状态
    AmllWebviewManager.instance.isReady.addListener(_onWebviewReady);
    if (AmllWebviewManager.instance.isReady.value) _syncAll();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _player.addListener(_onPlayerUpdate);
    });
  }

  /// Webview 就绪后全量同步（首次启动即打开全屏播放器的场景）。
  void _onWebviewReady() {
    if (mounted && AmllWebviewManager.instance.isReady.value) _syncAll();
  }

  void _onPlayerUpdate() {
    if (!AmllWebviewManager.instance.isReady.value || !mounted) return;

    final currentId = _player.currentSong?.id;
    // 歌曲变化 或 歌词异步加载完成/清空 (指纹变化) 时同步歌词
    final lyricFp = _lyricFingerprint();
    if (currentId != _lastSongId || lyricFp != _lastLyricFp) {
      _lastSongId = currentId;
      _lastLyricFp = lyricFp;
      _syncCoverAndLyrics();
    }

    if (_player.isPlaying != _lastIsPlaying) {
      _lastIsPlaying = _player.isPlaying;
      _controller.executeScript(
          'if (window.setPlaying) window.setPlaying(${_player.isPlaying});');
    }

    // 节流: 进度同步最多每秒 5 次, 避免高频 executeScript 打满消息队列
    final posMs = _player.position.inMilliseconds;
    if ((posMs - _lastTimeSentMs).abs() >= 200) {
      _lastTimeSentMs = posMs;
      _controller.executeScript(
          'if (window.setCurrentTime) window.setCurrentTime($posMs);');
    }
  }

  /// 打开全屏播放器时全量同步当前状态（Webview 常驻, 可能残留上一首状态）。
  void _syncAll() {
    if (!AmllWebviewManager.instance.isReady.value || !mounted) return;
    _lastSongId = _player.currentSong?.id;
    _lastIsPlaying = _player.isPlaying;
    _lastLyricFp = _lyricFingerprint();
    _syncCoverAndLyrics();
    _controller.executeScript(
        'if (window.setPlaying) window.setPlaying(${_player.isPlaying});');
    _controller.executeScript(
        'if (window.setCurrentTime) window.setCurrentTime(${_player.position.inMilliseconds});');
  }

  /// 歌词内容指纹: krcLines 为空时为 'empty', 否则为 行数+首尾行时间。
  String _lyricFingerprint() {
    final lines = _player.krcLines;
    if (lines == null || lines.isEmpty) return 'empty';
    final first = lines.first.startTime;
    final lastStart = lines.last.startTime;
    final lastEnd = lines.last.startTime + lines.last.duration;
    return '${lines.length}:$first:$lastStart:$lastEnd';
  }

  void _syncCoverAndLyrics() {
    final coverUrl = _player.currentSong?.thumbnailCoverUrl;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      final proxyUrl =
          'http://127.0.0.1:${LocalServer.port}/proxy-image?url=${Uri.encodeComponent(coverUrl)}';
      _controller.executeScript(
          'if (window.setCover) window.setCover(${jsonEncode(proxyUrl)});');
    }

    if (_player.krcLines != null && _player.krcLines!.isNotEmpty) {
      final ttml = TtmlGenerator.generate(_player.krcLines!);
      _controller.executeScript(
          'if (window.setLyric) window.setLyric(${jsonEncode(ttml)});');
    } else {
      _controller.executeScript('if (window.setLyric) window.setLyric("");');
    }
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayerUpdate);
    AmllWebviewManager.instance.isReady.removeListener(_onWebviewReady);
    // 注意: 不 dispose _controller —— Webview 由 AmllWebviewManager 常驻管理
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 背景 Webview 由 DesktopShell 常驻层提供, 这里仅渲染控制条与返回按钮
    return Stack(
      children: [
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
        // 底部控制条 (Dart 层, 不依赖 WebView 渲染)
        Positioned(
          left: 32,
          right: 32,
          bottom: 24,
          child: _buildControlBar(),
        ),
      ],
    );
  }

  Widget _buildControlBar() {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) return const SizedBox.shrink();

        final durationMs = player.duration.inMilliseconds.toDouble();
        final posMs = (_dragPosMs ??
                player.position.inMilliseconds.toDouble())
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
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
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
                          onChangeStart: (v) =>
                              setState(() => _dragPosMs = v),
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
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
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
      cover = CachedNetworkImage(
        imageUrl: url,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        memCacheWidth: 104,
        memCacheHeight: 104,
        errorWidget: (_, __, ___) => _defaultCoverIcon(),
      );
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
      child: const Icon(Icons.music_note_rounded,
          size: 26, color: Colors.white70),
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

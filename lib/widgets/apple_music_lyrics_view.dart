import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import '../providers/player_provider.dart';
import '../utils/theme.dart';

/// 逐字卡拉OK高亮汉字/音节组件
class KaraokeWordWidget extends StatelessWidget {
  final LyricWord word;
  final Duration position;
  final TextStyle activeStyle;
  final TextStyle inactiveStyle;

  const KaraokeWordWidget({
    super.key,
    required this.word,
    required this.position,
    required this.activeStyle,
    required this.inactiveStyle,
  });

  @override
  Widget build(BuildContext context) {
    final startMs = word.start?.inMilliseconds ?? 0;
    final endMs = word.end?.inMilliseconds ?? 0;
    final curMs = position.inMilliseconds;

    if (curMs < startMs) {
      return Text(word.text, style: inactiveStyle);
    }
    if (curMs > endMs) {
      return Text(word.text, style: activeStyle);
    }

    final duration = endMs - startMs;
    final progress = duration > 0 ? (curMs - startMs) / duration : 0.0;

    return ShaderMask(
      blendMode: ui.BlendMode.srcIn,
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: [
            activeStyle.color ?? Colors.white,
            inactiveStyle.color ?? Colors.white54,
          ],
          stops: [progress, progress],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(bounds);
      },
      child: Text(
        word.text,
        style: activeStyle.copyWith(color: Colors.white),
      ),
    );
  }
}

/// 单行歌词容器
class LyricLineContainer extends StatelessWidget {
  final LyricLine line;
  final bool isActive;
  final bool isPlayed;
  final LyricStyle style;
  final double currentProgress;

  const LyricLineContainer({
    super.key,
    required this.line,
    required this.isActive,
    required this.isPlayed,
    required this.style,
    this.currentProgress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final scale = isActive ? 1.12 : 1.0;
    final opacity = isActive ? 1.0 : (isPlayed ? 0.62 : 0.32);

    Widget content;

    if (line.words != null && line.words!.isNotEmpty && isActive) {
      content = Consumer<PlayerProvider>(
        builder: (context, player, _) {
          return Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: line.words!.map((w) {
              return KaraokeWordWidget(
                word: w,
                position: player.position,
                activeStyle: style.activeStyle,
                inactiveStyle: style.textStyle,
              );
            }).toList(),
          );
        },
      );
    } else {
      final staticStyle = isActive
          ? style.activeStyle
          : (isPlayed
              ? style.textStyle.copyWith(color: Colors.white.withValues(alpha: 0.7))
              : style.textStyle);
      content = Text(
        line.text,
        style: staticStyle,
        textAlign: style.lineTextAlign,
      );
    }

    if (line.translation != null && line.translation!.isNotEmpty) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          content,
          const SizedBox(height: 6),
          Text(
            line.translation!,
            style: isActive
                ? style.translationStyle.copyWith(color: Colors.white70)
                : style.translationStyle,
            textAlign: style.lineTextAlign,
          ),
        ],
      );
    }

    return RepaintBoundary(
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 300),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: style.lineGap / 2),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// 仿 Apple Music (AMLL) 原生歌词滚动与高亮主视图
class AppleMusicLyricsView extends StatefulWidget {
  final LyricController controller;
  final LyricStyle style;

  const AppleMusicLyricsView({
    super.key,
    required this.controller,
    required this.style,
  });

  @override
  State<AppleMusicLyricsView> createState() => _AppleMusicLyricsViewState();
}

class _AppleMusicLyricsViewState extends State<AppleMusicLyricsView> {
  final ScrollController _scrollController = ScrollController();
  bool _isUserDragging = false;
  Timer? _dragEndTimer;
  int _centerIndex = 0;
  List<LyricLine> _lines = [];
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _lines = widget.controller.lyricNotifier.value?.lines ?? [];
    _activeIndex = widget.controller.activeIndexNotifiter.value;

    widget.controller.lyricNotifier.addListener(_onLyricModelChanged);
    widget.controller.activeIndexNotifiter.addListener(_onActiveIndexChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToActiveIndex(immediate: true);
    });
  }

  @override
  void dispose() {
    widget.controller.lyricNotifier.removeListener(_onLyricModelChanged);
    widget.controller.activeIndexNotifiter
        .removeListener(_onActiveIndexChanged);
    _scrollController.dispose();
    _dragEndTimer?.cancel();
    super.dispose();
  }

  void _onLyricModelChanged() {
    if (mounted) {
      setState(() {
        _lines = widget.controller.lyricNotifier.value?.lines ?? [];
      });
    }
  }

  void _onActiveIndexChanged() {
    if (mounted) {
      final newActive = widget.controller.activeIndexNotifiter.value;
      if (newActive != _activeIndex) {
        setState(() {
          _activeIndex = newActive;
        });
        if (!_isUserDragging) {
          _scrollToActiveIndex();
        }
      }
    }
  }

  void _scrollToActiveIndex({bool immediate = false}) {
    if (!_scrollController.hasClients || _lines.isEmpty) return;
    if (_activeIndex < 0 || _activeIndex >= _lines.length) return;

    final double estimateHeight = widget.style.lineGap + 48.0;
    final double viewportHeight = _scrollController.position.viewportDimension;
    final double targetOffset =
        (_activeIndex * estimateHeight) - (viewportHeight * 0.38);
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double finalOffset = targetOffset.clamp(0.0, maxScroll);

    if (immediate) {
      _scrollController.jumpTo(finalOffset);
    } else {
      _scrollController.animateTo(
        finalOffset,
        duration: widget.style.scrollDuration,
        curve: widget.style.scrollCurve,
      );
    }
  }

  void _calculateCenterIndex() {
    if (!_scrollController.hasClients || _lines.isEmpty) return;
    final double offset = _scrollController.offset;
    final double viewportHeight = _scrollController.position.viewportDimension;
    final double centerOffset = offset + (viewportHeight * 0.4);
    final double estimateHeight = widget.style.lineGap + 48.0;
    final int index =
        (centerOffset / estimateHeight).round().clamp(0, _lines.length - 1);
    if (index != _centerIndex) {
      setState(() {
        _centerIndex = index;
      });
    }
  }

  void _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        _dragEndTimer?.cancel();
        setState(() {
          _isUserDragging = true;
        });
      }
    } else if (notification is ScrollUpdateNotification) {
      if (_isUserDragging) {
        _calculateCenterIndex();
      }
    } else if (notification is ScrollEndNotification) {
      if (_isUserDragging) {
        _dragEndTimer?.cancel();
        _dragEndTimer = Timer(const Duration(milliseconds: 3500), () {
          if (mounted) {
            setState(() {
              _isUserDragging = false;
            });
            _scrollToActiveIndex();
          }
        });
      }
    }
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00';
    final s = d.inSeconds % 60;
    final m = d.inMinutes;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_lines.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.center,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                _onScrollNotification(notification);
                return false;
              },
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  vertical: constraints.maxHeight * 0.45,
                  horizontal: 24,
                ),
                itemCount: _lines.length,
                itemBuilder: (context, index) {
                  final line = _lines[index];
                  final isActive = index == _activeIndex;
                  final isPlayed = index < _activeIndex;
                  return LyricLineContainer(
                    line: line,
                    isActive: isActive,
                    isPlayed: isPlayed,
                    style: widget.style,
                  );
                },
              ),
            ),

            // 手动拖拽：悬浮中线
            if (_isUserDragging)
              Positioned(
                left: 16,
                right: 16,
                child: IgnorePointer(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: 0.25),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 拖拽时：播放按钮
            if (_isUserDragging &&
                _centerIndex >= 0 &&
                _centerIndex < _lines.length)
              Positioned(
                right: 28,
                child: M3PressScale(
                  child: FloatingActionButton.small(
                    elevation: 4,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      final line = _lines[_centerIndex];
                      context.read<PlayerProvider>().seek(line.start);
                      widget.controller.setProgress(line.start);
                      setState(() {
                        _isUserDragging = false;
                        _activeIndex = _centerIndex;
                      });
                      _scrollToActiveIndex();
                    },
                    child: const Icon(Icons.play_arrow_rounded, size: 22),
                  ),
                ),
              ),

            // 拖拽时：时间标签
            if (_isUserDragging &&
                _centerIndex >= 0 &&
                _centerIndex < _lines.length)
              Positioned(
                left: 28,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatDuration(_lines[_centerIndex].start),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white70,
                          fontFamily: 'HarmonyOS Sans',
                          fontFeatures: const [
                            ui.FontFeature.tabularFigures()
                          ],
                        ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/lyric_line.dart';
import 'lyric_line_painter.dart';

/// Apple Music-style lyrics widget.
///
/// 设计要点（对比主流软件）:
///   - 当前行位于视口上方 35%（Apple Music 风格），下方留空间给即将唱的行
///   - 首次加载等 build 完成后再滚动，避免 GlobalKey 未就绪
///   - 动画保护，连续更新不互相打断
///   - 手动拖拽后 5 秒自动恢复滚动（比 3 秒更宽松）
class AMLyricsView extends StatefulWidget {
  final List<LyricLine> lyrics;
  final int currentLineIndex;
  final double currentLineProgress;
  final bool isLoading;
  final ValueChanged<Duration> onSeek;

  const AMLyricsView({
    super.key,
    required this.lyrics,
    required this.currentLineIndex,
    required this.currentLineProgress,
    required this.isLoading,
    required this.onSeek,
  });

  @override
  State<AMLyricsView> createState() => _AMLyricsViewState();
}

class _AMLyricsViewState extends State<AMLyricsView> {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _itemKeys = [];
  bool _autoScroll = true;
  Timer? _autoScrollResumeTimer;
  bool _isAnimating = false;
  int _lastLyricLength = 0;

  /// Apple Music 风格：当前行位于视口上方 35% 处（不是正中央）
  static const double _sweetSpotRatio = 0.35;

  // Text styles for measurement
  static const TextStyle _currentStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );
  static const TextStyle _otherStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  @override
  void dispose() {
    _scrollController.dispose();
    _autoScrollResumeTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _syncKeys();
  }

  @override
  void didUpdateWidget(covariant AMLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 歌词列表变化（长度或引用变化）时重建 keys
    if (widget.lyrics.length != _lastLyricLength ||
        (widget.lyrics.isNotEmpty && oldWidget.lyrics != widget.lyrics)) {
      _autoScroll = true;
      _autoScrollResumeTimer?.cancel();
      _syncKeys();
      // 等 build 完成后再滚动，确保 GlobalKey 的 context 有效
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentLine());
    } else {
      // 仅仅是 currentLineIndex / progress 变化，直接滚动
      _scrollToCurrentLine();
    }
  }

  /// 同步 _itemKeys 长度与 lyrics 匹配
  void _syncKeys() {
    _lastLyricLength = widget.lyrics.length;
    while (_itemKeys.length < widget.lyrics.length) {
      _itemKeys.add(GlobalKey());
    }
    while (_itemKeys.length > widget.lyrics.length) {
      _itemKeys.removeLast();
    }
  }

  /// 滚动到当前行
  ///
  /// [snap] : 是否为"回到当前"操作（快速）还是跟随播放（平滑）
  ///   - snap=true  : 250ms easeOutCubic  → FAB / 自动恢复
  ///   - snap=false : 400ms easeInOutCubic → 播放进度跟踪
  void _scrollToCurrentLine({bool snap = false}) {
    if (!_autoScroll || !_scrollController.hasClients) return;
    if (widget.lyrics.isEmpty) return;
    if (_isAnimating) return; // 正在动画中，跳过避免冲突

    final idx = widget.currentLineIndex.clamp(0, widget.lyrics.length - 1);
    final viewportHeight = _scrollController.position.viewportDimension;

    // 累加当前行之前所有行的实际高度
    double offset = 0;
    for (int i = 0; i < idx && i < _itemKeys.length; i++) {
      final key = _itemKeys[i];
      final ctx = key.currentContext;
      if (ctx != null && ctx.findRenderObject() is RenderBox) {
        offset += (ctx.findRenderObject() as RenderBox).size.height;
      } else {
        offset += 56;
      }
    }

    // 当前行高度
    double currentLineHeight = 56;
    if (idx < _itemKeys.length) {
      final ctx = _itemKeys[idx].currentContext;
      if (ctx != null && ctx.findRenderObject() is RenderBox) {
        currentLineHeight = (ctx.findRenderObject() as RenderBox).size.height;
      }
    }

    // ListView 的 top padding（与 build 中的 padding 一致）
    final topPadding = MediaQuery.of(context).size.height * 0.12;

    // Apple Music 风格：当前行位于视口上方 35% 处
    // 当前行在列表中的位置 = topPadding + offset
    // 目标：viewportPosition = sweetSpot
    // (topPadding + offset) - target + currentLineHeight/2 = sweetSpot
    // target = topPadding + offset - sweetSpot + currentLineHeight / 2
    final sweetSpot = viewportHeight * _sweetSpotRatio;
    final target = topPadding + offset - sweetSpot + currentLineHeight / 2;

    final clamped = target.clamp(0.0, _scrollController.position.maxScrollExtent);

    _isAnimating = true;
    _scrollController
        .animateTo(clamped,
            duration: snap ? const Duration(milliseconds: 250) : const Duration(milliseconds: 400),
            curve: snap ? Curves.easeOutCubic : Curves.easeInOutCubic)
        .whenComplete(() {
      _isAnimating = false;
    });
  }

  void _onUserScroll() {
    if (!_autoScroll) return;
    _autoScroll = false;
    _autoScrollResumeTimer?.cancel();
    _autoScrollResumeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _autoScroll = true);
        _scrollToCurrentLine(snap: true);
      }
    });
  }

  Color _dimColor(int distanceFromCurrent) {
    if (distanceFromCurrent == 0) return Colors.white;
    if (distanceFromCurrent == 1) return Colors.white54;
    return Colors.white24;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }

    if (widget.lyrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lyrics_outlined, size: 48, color: Colors.white54),
            const SizedBox(height: 16),
            const Text('暂无歌词', style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification &&
                notification.dragDetails != null) {
              _onUserScroll();
            }
            return false;
          },
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).size.height * 0.12,
              bottom: MediaQuery.of(context).size.height * 0.35,
            ),
            itemCount: widget.lyrics.length,
            itemBuilder: (context, index) {
              final line = widget.lyrics[index];
              final isCurrent = index == widget.currentLineIndex;
              final distance = (index - widget.currentLineIndex).abs();

              return Container(
                key: _itemKeys[index],
                child: isCurrent
                    ? _buildCurrentLine(line)
                    : _buildOtherLine(line, distance),
              );
            },
          ),
        ),

        if (!_autoScroll)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.small(
              heroTag: 'lyric_resume',
              backgroundColor: Colors.white24,
              onPressed: () {
                setState(() => _autoScroll = true);
                _autoScrollResumeTimer?.cancel();
                _scrollToCurrentLine(snap: true);
              },
              child: const Icon(Icons.vertical_align_center, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildCurrentLine(LyricLine line) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      child: GestureDetector(
        onTap: () => widget.onSeek(line.time),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tp = TextPainter(
              text: TextSpan(text: line.text, style: _currentStyle),
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: constraints.maxWidth);

            return CustomPaint(
              painter: LyricLinePainter(
                text: line.text,
                progress: widget.currentLineProgress,
                fillColor: Colors.white,
                unfilledColor: Colors.white30,
                textStyle: _currentStyle,
                textAlign: TextAlign.left,
                maxWidth: constraints.maxWidth,
              ),
              size: Size(constraints.maxWidth, tp.height),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOtherLine(LyricLine line, int distance) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
      child: GestureDetector(
        onTap: () => widget.onSeek(line.time),
        child: Text(
          line.text,
          textAlign: TextAlign.left,
          style: _otherStyle.copyWith(
            color: _dimColor(distance),
          ),
        ),
      ),
    );
  }
}

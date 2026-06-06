import 'dart:async';
import 'package:flutter/material.dart';
import '../models/lyric_line.dart';
import 'lyric_line_painter.dart';

/// Apple Music-style lyrics view with per-word karaoke fill.
///
/// Design (adapted from Linx-Music):
///   - Current line sits at ~35% of the viewport (Apple Music style)
///   - Line heights tracked by [MeasureSize] instead of GlobalKey
///   - Uses [widget.position] directly (no ticker — avoids sync lag after seek)
///   - Scroll only when the active line changes (not on every progress tick)
///   - User drag pauses auto-scroll; resumes after a timeout
class AMLyricsView extends StatefulWidget {
  final List<LyricLine> lyrics;
  final Duration position;
  final bool isLoading;
  final ValueChanged<Duration> onSeek;

  const AMLyricsView({
    super.key,
    required this.lyrics,
    required this.position,
    required this.isLoading,
    required this.onSeek,
  });

  @override
  State<AMLyricsView> createState() => _AMLyricsViewState();
}

class _AMLyricsViewState extends State<AMLyricsView> {
  final ScrollController _scrollController = ScrollController();
  final List<double> _lineHeights = [];

  bool _autoScroll = true;
  bool _isAnimating = false;
  Timer? _resumeTimer;

  int _currentLineIndex = 0;

  static const double _sweetSpotRatio = 0.50;
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
  static const TextStyle _translationStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w300,
    height: 1.2,
    color: Colors.white38,
  );

  @override
  void initState() {
    super.initState();
    _updateLineIndex();
  }

  @override
  void didUpdateWidget(covariant AMLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldIndex = _currentLineIndex;
    _updateLineIndex();

    if (widget.lyrics != oldWidget.lyrics) {
      _lineHeights.clear();
      _autoScroll = true;
      _resumeTimer?.cancel();
      _currentLineIndex = 0;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToCurrent(snap: true));
    } else if (_currentLineIndex != oldIndex && _autoScroll) {
      _scrollToCurrent();
    }
  }

  void _updateLineIndex() {
    if (widget.lyrics.isEmpty) {
      _currentLineIndex = 0;
      return;
    }
    final idx = widget.lyrics.lastIndexWhere(
      (l) => widget.position >= l.startTime,
    );
    _currentLineIndex = idx == -1 ? 0 : idx;
  }

  void _scrollToCurrent({bool snap = false}) {
    if (!_autoScroll || !_scrollController.hasClients) return;
    if (_isAnimating) return;
    if (widget.lyrics.isEmpty) return;

    final idx = _currentLineIndex.clamp(0, widget.lyrics.length - 1);
    final vh = _scrollController.position.viewportDimension;
    final measured = _lineHeights.length;

    double offset = 0;
    // Sum measured heights up to idx
    for (int i = 0; i < idx && i < measured; i++) {
      offset += _lineHeights[i];
    }
    // Estimate unmeasured lines using average measured height
    if (idx >= measured) {
      final avg = measured > 0
          ? _lineHeights.fold<double>(0, (s, h) => s + h) / measured
          : 56.0;
      offset += avg * (idx - measured + 1);
    }

    final currentH =
        idx < measured ? _lineHeights[idx] : 56.0;
    final topPad = (MediaQuery.of(context).size.height * 0.12).clamp(60, 140);
    final sweetSpot = vh * _sweetSpotRatio;

    final target = (topPad + offset - sweetSpot + currentH / 2)
        .clamp(0.0, _scrollController.position.maxScrollExtent);

    _isAnimating = true;
    _scrollController
        .animateTo(
          target,
          duration: snap
              ? const Duration(milliseconds: 250)
              : const Duration(milliseconds: 400),
          curve: snap ? Curves.easeOutCubic : Curves.easeInOutCubic,
        )
        .then((_) => _isAnimating = false)
        .catchError((_) => _isAnimating = false);
  }

  // ── User interaction ──

  void _onUserScroll() {
    if (!_autoScroll) return;
    _autoScroll = false;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _autoScroll = true);
        _scrollToCurrent(snap: true);
      }
    });
  }

  Color _dimColor(int distance) {
    if (distance == 0) return Colors.white;
    if (distance == 1) return Colors.white54;
    return Colors.white24;
  }

  // ── Build ──

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
            const Icon(Icons.lyrics_outlined, size: 48, color: Colors.white54),
            const SizedBox(height: 16),
            const Text('暂无歌词',
                style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollStartNotification &&
                n.dragDetails != null &&
                _autoScroll) {
              _onUserScroll();
            }
            return false;
          },
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.only(
              top: (MediaQuery.of(context).size.height * 0.12).clamp(60, 140),
              bottom: (MediaQuery.of(context).size.height * 0.35).clamp(120, 280),
            ),
            itemCount: widget.lyrics.length,
            itemBuilder: (context, index) {
              final line = widget.lyrics[index];
              final isCurrent = index == _currentLineIndex;
              final distance = (index - _currentLineIndex).abs();

              return _buildLine(line, index, isCurrent, distance);
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
                _resumeTimer?.cancel();
                _scrollToCurrent(snap: true);
              },
              child: const Icon(Icons.vertical_align_center,
                  color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildLine(LyricLine line, int index, bool isCurrent, int distance) {
    return MeasureSize(
      onChange: (size) {
        if (_lineHeights.length <= index) {
          _lineHeights.add(size.height);
        } else {
          _lineHeights[index] = size.height;
        }
      },
      child: GestureDetector(
        onTap: () => widget.onSeek(line.startTime),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCurrent)
                _buildCurrentLine(line)
              else
                _buildOtherLine(line, distance),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentLine(LyricLine line) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;

        // 计算实际多行高度，避免长歌词重叠
        final h = LyricLinePainter.layoutHeight(
          line.spans,
          _currentStyle,
          Directionality.of(context),
          maxW,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              painter: LyricLinePainter(
                spans: line.spans,
                position: widget.position, // 直通，不经过 Ticker
                lineStart: line.startTime,
                lineEnd: line.endTime,
                textStyle: _currentStyle,
                textDirection: Directionality.of(context),
                maxWidth: maxW,
              ),
              size: Size(maxW, h > 0 ? h : 34),
            ),
            if (line.translatedText != null &&
                line.translatedText!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  line.translatedText!,
                  textAlign: TextAlign.left,
                  style: _translationStyle,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildOtherLine(LyricLine line, int distance) {
    final color = _dimColor(distance);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          line.text,
          textAlign: TextAlign.left,
          style: _otherStyle.copyWith(color: color),
        ),
        if (line.translatedText != null &&
            line.translatedText!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              line.translatedText!,
              textAlign: TextAlign.left,
              style: _translationStyle.copyWith(
                color: color.withValues(alpha: 0.6),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _resumeTimer?.cancel();
    super.dispose();
  }
}

// ── MeasureSize helper ──

/// Calls [onChange] whenever the child's layout size changes.
class MeasureSize extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size> onChange;

  const MeasureSize({super.key, required this.onChange, required this.child});

  @override
  State<MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  Size? _last;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = context.size;
      if (size != null &&
          (_last == null ||
              (_last!.height - size.height).abs() > 0.5 ||
              (_last!.width - size.width).abs() > 0.5)) {
        _last = size;
        widget.onChange(size);
      }
    });
    return widget.child;
  }
}

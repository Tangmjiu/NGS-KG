import 'dart:async';
import 'package:flutter/material.dart';
import '../models/lyric_line.dart';
import 'lyric_line_painter.dart';

/// Apple Music-style lyrics widget.
///
/// Displays scrolling lyrics with an animated karaoke fill effect on the
/// current line. Previous / upcoming lines are dimmed progressively based
/// on distance from the active line. Auto-scroll keeps the current line
/// centred; manual drag pauses auto-scroll for 3 seconds.
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
  bool _autoScroll = true;
  Timer? _autoScrollResumeTimer;

  /// Estimated line height (font size + padding) used for scroll calculations.
  static const double _currentLineHeight = 60.0; // 24px font + 24px padding
  static const double _otherLineHeight = 42.0; // 16px font + 20px padding

  @override
  void dispose() {
    _scrollController.dispose();
    _autoScrollResumeTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AMLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lyrics != oldWidget.lyrics) {
      _autoScroll = true;
      _autoScrollResumeTimer?.cancel();
    }
    _scrollToCurrentLine();
  }

  void _scrollToCurrentLine() {
    if (!_autoScroll || !_scrollController.hasClients) return;
    if (widget.lyrics.isEmpty) return;

    final viewportHeight = _scrollController.position.viewportDimension;

    // Calculate offset to the current line, accounting for variable line heights.
    final offset = widget.currentLineIndex * _otherLineHeight;
    final target = offset - viewportHeight / 2 + _currentLineHeight / 2;

    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  void _onUserScroll() {
    if (!_autoScroll) return;
    _autoScroll = false;
    _autoScrollResumeTimer?.cancel();
    _autoScrollResumeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _autoScroll = true);
        _scrollToCurrentLine();
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
    // Loading state
    if (widget.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }

    // Empty state
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
              top: MediaQuery.of(context).size.height * 0.15,
              bottom: MediaQuery.of(context).size.height * 0.15,
            ),
            itemCount: widget.lyrics.length,
            itemBuilder: (context, index) {
              final line = widget.lyrics[index];
              final isCurrent = index == widget.currentLineIndex;
              final distance = (index - widget.currentLineIndex).abs();

              if (isCurrent) {
                return _buildCurrentLine(line);
              } else {
                return _buildOtherLine(line, distance);
              }
            },
          ),
        ),

        // "回到当前" FAB when auto-scroll is paused
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
                _scrollToCurrentLine();
              },
              child: const Icon(Icons.vertical_align_center, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildCurrentLine(LyricLine line) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
      child: GestureDetector(
        onTap: () => widget.onSeek(line.time),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              painter: LyricLinePainter(
                text: line.text,
                progress: widget.currentLineProgress,
                fillColor: Colors.white,
                unfilledColor: Colors.white30,
                textStyle: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxWidth: constraints.maxWidth,
              ),
              size: Size(
                constraints.maxWidth,
                36.0, // 24px font * 1.4 line height ≈ 34, padded to 36
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOtherLine(LyricLine line, int distance) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 32),
      child: GestureDetector(
        onTap: () => widget.onSeek(line.time),
        child: Text(
          line.text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.4,
            color: _dimColor(distance),
          ),
        ),
      ),
    );
  }
}

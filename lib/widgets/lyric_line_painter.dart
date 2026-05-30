import 'package:flutter/material.dart';
import '../models/lyric_line.dart';

/// Renders a single lyric line with per-span karaoke fill effect.
///
/// Each span is painted in three layers:
/// 1. Dimmed (inactive) text – full span.
/// 2. Bright (completed) text – painted on top for spans fully in the past.
/// 3. Actively-filling span – clipped horizontally with a soft gradient edge.
class LyricLinePainter extends CustomPainter {
  final List<LyricSpan> spans;
  final Duration position;
  final Duration lineStart;
  final Duration lineEnd;
  final TextStyle textStyle;
  final TextDirection textDirection;
  final double maxWidth;

  const LyricLinePainter({
    required this.spans,
    required this.position,
    required this.lineStart,
    required this.lineEnd,
    required this.textStyle,
    required this.textDirection,
    required this.maxWidth,
  });

  /// Pre-compute the multi-line layout height so callers can size correctly.
  static double layoutHeight(
    List<LyricSpan> spans,
    TextStyle style,
    TextDirection dir,
    double maxWidth,
  ) {
    if (spans.isEmpty) return 0;
    double x = 0, y = 0, rowH = 0;
    for (final span in spans) {
      // 先用无限制宽度计算自然宽度
      final tp = TextPainter(
        text: TextSpan(text: span.text, style: style.copyWith(color: Colors.white30)),
        textDirection: dir,
      )..layout();
      final spanWidth = tp.width;
      // 需要换行且不是行首
      if (x + spanWidth > maxWidth && x > 0) {
        y += rowH;
        x = 0;
        rowH = 0;
      }
      // 用剩余宽度重新布局（让 TextPainter 自行换行）
      tp.layout(maxWidth: maxWidth - x);
      x += tp.width;
      if (tp.height > rowH) rowH = tp.height;
    }
    return y + rowH;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (spans.isEmpty) return;

    final isLineCompleted = position >= lineEnd;

    // Pre-compute layout for every span
    final layouts = <_SpanLayout>[];
    double x = 0;
    double y = 0;
    double rowHeight = 0;

    for (final span in spans) {
      // 先用无限制宽度计算是否需要换行
      final measure = TextPainter(
        text: TextSpan(text: span.text, style: textStyle.copyWith(color: Colors.white30)),
        textDirection: textDirection,
      )..layout();
      final spanWidth = measure.width;

      if (x + spanWidth > maxWidth && x > 0) {
        y += rowHeight;
        x = 0;
        rowHeight = 0;
      }

      // 用剩余宽度创建实际 TextPainter
      final inactive = TextPainter(
        text: TextSpan(text: span.text, style: textStyle.copyWith(color: Colors.white30)),
        textDirection: textDirection,
      )..layout(maxWidth: maxWidth - x);

      final active = TextPainter(
        text: TextSpan(text: span.text, style: textStyle.copyWith(color: Colors.white)),
        textDirection: textDirection,
      )..layout(maxWidth: maxWidth - x);

      layouts.add(_SpanLayout(
        span: span,
        offset: Offset(x, y),
        width: inactive.width,
        height: inactive.height,
        inactivePainter: inactive,
        activePainter: active,
      ));

      x += inactive.width;
      if (inactive.height > rowHeight) rowHeight = inactive.height;
    }

    // Paint each span
    for (final l in layouts) {
      final progress = l.span.getSpanProgress(position);
      final offset = l.offset;

      if (isLineCompleted || progress >= 1.0) {
        l.activePainter.paint(canvas, offset);
      } else if (progress <= 0.0 || position < lineStart) {
        l.inactivePainter.paint(canvas, offset);
      } else {
        _paintFillingToken(canvas, l, progress);
      }
    }
  }

  void _paintFillingToken(
    Canvas canvas,
    _SpanLayout token,
    double progress,
  ) {
    const double softEdgeWidth = 14.0;
    final offset = token.offset;

    token.inactivePainter.paint(canvas, offset);

    final filledWidth = token.width * progress;
    final solidW = (filledWidth - softEdgeWidth).clamp(0.0, token.width);
    final fadeW = (filledWidth - solidW).clamp(0.0, token.width);

    if (solidW > 0) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(offset.dx, offset.dy, solidW, token.height));
      token.activePainter.paint(canvas, offset);
      canvas.restore();
    }

    if (fadeW <= 0) return;
    final fadeRect = Rect.fromLTWH(offset.dx + solidW, offset.dy, fadeW, token.height);
    canvas.saveLayer(fadeRect, Paint());
    canvas.save();
    canvas.clipRect(fadeRect);
    token.activePainter.paint(canvas, offset);
    canvas.restore();
    canvas.drawRect(
      fadeRect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.white, Colors.transparent],
        ).createShader(fadeRect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LyricLinePainter oldDelegate) {
    return oldDelegate.spans != spans ||
        oldDelegate.position != position ||
        oldDelegate.lineStart != lineStart ||
        oldDelegate.lineEnd != lineEnd ||
        oldDelegate.textStyle != textStyle ||
        oldDelegate.maxWidth != maxWidth;
  }
}

class _SpanLayout {
  final LyricSpan span;
  final Offset offset;
  final double width;
  final double height;
  final TextPainter inactivePainter;
  final TextPainter activePainter;

  const _SpanLayout({
    required this.span,
    required this.offset,
    required this.width,
    required this.height,
    required this.inactivePainter,
    required this.activePainter,
  });
}

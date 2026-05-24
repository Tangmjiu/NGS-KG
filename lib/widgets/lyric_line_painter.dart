import 'package:flutter/material.dart';

/// A [CustomPainter] that renders lyric text with an Apple Music-style
/// karaoke fill effect.
///
/// The text is drawn in two layers:
///   1. Dimmed **unfilled** text at full width (the base layer).
///   2. Brightly-colored **filled** text, clipped horizontally to
///      [progress] × text width and painted on top.
///
/// [progress] must be in `[0.0, 1.0]` — 0.0 is fully unfilled,
/// 1.0 is fully filled.
///
/// Usage inside a [CustomPaint] widget:
/// ```dart
/// CustomPaint(
///   painter: LyricLinePainter(
///     text: 'Never gonna give you up',
///     progress: 0.42,
///     fillColor: Colors.white,
///     unfilledColor: Colors.white30,
///     textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
///     textAlign: TextAlign.center,
///     maxWidth: MediaQuery.of(context).size.width,
///   ),
///   size: Size(maxWidth, textHeight),
/// )
/// ```
class LyricLinePainter extends CustomPainter {
  /// The lyric text to render.
  final String text;

  /// Playback progress for this line, `0.0` (none filled) to `1.0` (fully filled).
  final double progress;

  /// The accent color used for the filled (already-sung) portion of the text.
  final Color fillColor;

  /// The dimmed color used for the unfilled (yet-to-be-sung) portion.
  final Color unfilledColor;

  /// Base text style controlling font size, weight, letter-spacing, etc.
  /// [TextStyle.color] on this style is **ignored** — use [fillColor]
  /// and [unfilledColor] instead.
  final TextStyle textStyle;

  /// How the text is horizontally aligned within [maxWidth].
  final TextAlign textAlign;

  /// Available width for text layout and alignment.
  final double maxWidth;

  const LyricLinePainter({
    required this.text,
    required this.progress,
    required this.fillColor,
    required this.unfilledColor,
    required this.textStyle,
    required this.textAlign,
    required this.maxWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;

    // Build the two styled spans. Only colour differs —
    // layout metrics are identical, so TextPainter measurements
    // are consistent between layers.
    final unfilledSpan =
        TextSpan(text: text, style: textStyle.copyWith(color: unfilledColor));
    final filledSpan =
        TextSpan(text: text, style: textStyle.copyWith(color: fillColor));

    // TextAlign is forced to left here because we handle alignment
    // manually via the paint offset. This keeps the clip-rect
    // calculation trivial and correct for every alignment variant.
    final textPainter = TextPainter(
      text: unfilledSpan,
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    final textWidth = textPainter.width;
    final textOffset = Offset(_offsetX(textWidth), 0);

    // ── 1. Dimmed (unfilled) layer ──
    textPainter.paint(canvas, textOffset);

    // ── 2. Bright (filled) layer, clipped to progress ──
    final filledWidth = (progress * textWidth).clamp(0.0, textWidth);

    // Swap in the filled span and re-layout (width doesn't change
    // since only colour is different).
    textPainter.text = filledSpan;
    textPainter.layout(maxWidth: maxWidth);

    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(textOffset.dx, 0, filledWidth, size.height),
    );
    textPainter.paint(canvas, textOffset);
    canvas.restore();
  }

  /// Computes the horizontal paint offset so the text appears aligned
  /// correctly within [maxWidth].
  double _offsetX(double textWidth) {
    switch (textAlign) {
      case TextAlign.left:
      case TextAlign.start:
      case TextAlign.justify:
        return 0;
      case TextAlign.center:
        return (maxWidth - textWidth) / 2;
      case TextAlign.right:
      case TextAlign.end:
        return maxWidth - textWidth;
    }
  }

  @override
  bool shouldRepaint(covariant LyricLinePainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.progress != progress ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.unfilledColor != unfilledColor ||
        oldDelegate.textStyle != textStyle ||
        oldDelegate.textAlign != textAlign ||
        oldDelegate.maxWidth != maxWidth;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LyricLinePainter &&
        other.text == text &&
        other.progress == progress &&
        other.fillColor == fillColor &&
        other.unfilledColor == unfilledColor &&
        other.textStyle == textStyle &&
        other.textAlign == textAlign &&
        other.maxWidth == maxWidth;
  }

  @override
  int get hashCode => Object.hash(
        text,
        progress,
        fillColor,
        unfilledColor,
        textStyle,
        textAlign,
        maxWidth,
      );
}

import 'package:flutter/material.dart';
import 'dart:math' as math;

class PlayingIndicator extends StatefulWidget {
  final Color? color;
  final double size;

  const PlayingIndicator({
    super.key,
    this.color,
    this.size = 24.0,
  });

  @override
  State<PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _EqualizerPainter(
              color: activeColor,
              progress: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _EqualizerPainter extends CustomPainter {
  final Color color;
  final double progress;

  _EqualizerPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final barCount = 4;
    final spacing = size.width * 0.15;
    final barWidth = (size.width - spacing * (barCount - 1)) / barCount;

    // Using sine waves with different phases and frequencies to simulate an equalizer
    for (int i = 0; i < barCount; i++) {
      final phase = i * math.pi / 2.0;
      final frequency = 1.0 + (i % 2) * 1.5;

      // Calculate height ratio between 0.3 and 1.0
      final heightRatio = 0.3 +
          0.7 *
              (math.sin(progress * math.pi * 2 * frequency + phase) * 0.5 +
                  0.5);

      final barHeight = size.height * heightRatio;

      final x = i * (barWidth + spacing);
      final y = size.height - barHeight;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );

      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EqualizerPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

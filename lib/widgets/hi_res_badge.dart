import 'package:flutter/material.dart';

/// Hi-Res Audio 徽标组件，显示在封面图左下角
///
/// 参考官方 Hi-Res 金标设计：圆形金底 + Hi-Res AUDIO 文字 + 白勾。
class HiResBadge extends StatelessWidget {
  final double size;

  const HiResBadge({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFD700), // 金色
            Color(0xFFFFA500), // 橙金
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _HiResPainter(),
      ),
    );
  }
}

class _HiResPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.width / 36; // 以 36px 为基准

    // 白勾路径
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final checkPath = Path()
      ..moveTo(cx - 6 * scale, cy)
      ..lineTo(cx - 2.5 * scale, cy + 4 * scale)
      ..lineTo(cx + 6.5 * scale, cy - 4 * scale);
    canvas.drawPath(checkPath, checkPaint);

    // "Hi-Res" 文字
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Hi-Res',
        style: TextStyle(
          color: Colors.white,
          fontSize: 6.5 * scale,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2 * scale,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(cx - textPainter.width / 2, cy + 4 * scale),
    );

    // "AUDIO"
    final audioPainter = TextPainter(
      text: TextSpan(
        text: 'AUDIO',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 3.2 * scale,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8 * scale,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    audioPainter.layout();
    audioPainter.paint(
      canvas,
      Offset(cx - audioPainter.width / 2, cy + 9.8 * scale),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

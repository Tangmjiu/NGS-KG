import 'package:flutter/material.dart';

/// Hi-Res Audio 官方徽标
///
/// 日本音频协会（JAS）官方设计：黑底圆角矩形 + 金色顶部横条
/// + 金色 "Hi-Res" 文字 + 白色 "AUDIO" 文字
class HiResBadge extends StatelessWidget {
  /// 徽标高度，宽度自动按官方比例 2.5:1
  final double height;

  const HiResBadge({super.key, this.height = 28});

  @override
  Widget build(BuildContext context) {
    final width = height * 2.5;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(height * 0.08),
        border: Border.all(color: const Color(0xFFC8A84E), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 金色顶部横条
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: height * 0.28,
              color: const Color(0xFFC8A84E),
            ),
          ),
          // "Hi-Res" 文字 — 金色
          Positioned(
            left: 0,
            right: 0,
            top: height * 0.30,
            child: Text(
              'Hi-Res',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFC8A84E),
                fontSize: height * 0.38,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          ),
          // "AUDIO" 文字 — 白色
          Positioned(
            left: 0,
            right: 0,
            bottom: height * 0.08,
            child: Text(
              'AUDIO',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: height * 0.18,
                fontWeight: FontWeight.w700,
                letterSpacing: width * 0.035,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

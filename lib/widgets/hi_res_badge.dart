import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/theme_assets.dart';

/// Hi-Res Audio 官方徽标
///
/// 优先使用 [ThemeAssets.hiResBadge] 路径中的图片，
/// 支持 SVG 和 PNG/JPG 格式，无自定义图片时回退到官方 SVG 内置资源。
class HiResBadge extends StatelessWidget {
  /// 徽标高度，宽度自动按比例
  final double height;

  const HiResBadge({super.key, this.height = 28});

  @override
  Widget build(BuildContext context) {
    final assetPath = ThemeAssets.hiResBadge;
    if (assetPath.isEmpty) return const SizedBox.shrink();

    final width = height * 2.5;
    return SizedBox(
      width: width,
      height: height,
      child: _buildImage(assetPath),
    );
  }

  Widget _buildImage(String assetPath) {
    if (assetPath.endsWith('.svg')) {
      if (assetPath.startsWith('assets/')) {
        return SvgPicture.asset(
          assetPath,
          width: height * 2.5,
          height: height,
          fit: BoxFit.contain,
        );
      } else {
        return SvgPicture.file(
          File(assetPath),
          width: height * 2.5,
          height: height,
          fit: BoxFit.contain,
        );
      }
    }

    // PNG/JPG fallback
    if (assetPath.startsWith('assets/')) {
      return Image.asset(
        assetPath,
        width: height * 2.5,
        height: height,
        fit: BoxFit.contain,
      );
    } else {
      return Image.file(
        File(assetPath),
        width: height * 2.5,
        height: height,
        fit: BoxFit.contain,
      );
    }
  }
}

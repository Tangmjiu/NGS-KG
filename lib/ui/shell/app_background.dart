// SPDX-License-Identifier: MIT
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../theme/theme_assets.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    if (ThemeAssets.playerBg.isEmpty) return const SizedBox.shrink();
    final background = themeImageProvider(ThemeAssets.playerBg);
    return RepaintBoundary(
      child: ClipRect(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Image(
            image: ResizeImage(background, width: 720),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

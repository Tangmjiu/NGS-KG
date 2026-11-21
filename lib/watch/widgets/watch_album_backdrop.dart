// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Album art extends under the glass. Text sits in the darker lower half.
class WatchAlbumBackdrop extends StatelessWidget {
  const WatchAlbumBackdrop({super.key, this.art, this.tone});
  final String? art;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? Theme.of(context).colorScheme.primary;
    final pixels =
        (MediaQuery.sizeOf(context).shortestSide *
                MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(1, 640);
    final uri = Uri.tryParse(art ?? '');
    final local = uri?.scheme == 'file' || (art?.startsWith('/') ?? false);
    final web = uri?.scheme == 'https' || uri?.scheme == 'http';
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.05, -0.34),
                  radius: 0.83,
                  colors: [
                    Color.lerp(const Color(0xff314744), color, .43)!,
                    const Color(0xff131d22),
                    Colors.black,
                  ],
                  stops: const [0, .69, 1],
                ),
              ),
            ),
            if (web)
              CachedNetworkImage(
                imageUrl: art!,
                fit: BoxFit.cover,
                memCacheWidth: pixels,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            if (local)
              Image.file(
                File(uri!.scheme == 'file' ? uri.toFilePath() : art!),
                fit: BoxFit.cover,
                cacheWidth: pixels,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            if (web || local)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x50000000),
                      Color(0x80000000),
                      Color(0xc9000000),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

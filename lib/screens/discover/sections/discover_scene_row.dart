// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../../../models/scene_category.dart';
import 'discover_media_rail.dart';

class DiscoverSceneRow extends StatelessWidget {
  final List<SceneCategory> scenes;

  const DiscoverSceneRow({super.key, required this.scenes});

  @override
  Widget build(BuildContext context) => DiscoverMediaRail(
        compact: true,
        items: scenes
            .map((scene) => DiscoverMediaItem(
                  title: scene.name,
                  imageUrl: scene.iconUrl,
                  icon: Icons.explore_rounded,
                  onTap: () => Navigator.pushNamed(context, '/fm'),
                ))
            .toList(growable: false),
      );
}

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/scene_category.dart';
import '../../../widgets/horizontal_scroll_list.dart';

/// 场景音乐 — 横向滚动图标卡片
class DiscoverSceneRow extends StatelessWidget {
  final List<SceneCategory> scenes;

  const DiscoverSceneRow({super.key, required this.scenes});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return HorizontalScrollList(
      height: 100,
      cardWidth: 80,
      itemCount: scenes.length,
      itemBuilder: (_, i) {
        final scene = scenes[i];
        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/fm'),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: scene.iconUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: scene.iconUrl!,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 64,
                            height: 64,
                            color: cs.primaryContainer
                                .withValues(alpha: 0.4),
                          ),
                          errorWidget: (_, __, ___) => Icon(
                            Icons.explore,
                            color: cs.primary,
                            size: 28,
                          ),
                        ),
                      )
                    : Icon(Icons.explore, color: cs.primary, size: 28),
              ),
              const SizedBox(height: 6),
              Text(
                scene.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: cs.onSurface),
              ),
            ],
          ),
        );
      },
    );
  }
}

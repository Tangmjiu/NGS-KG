import 'package:flutter/material.dart';
import '../../../utils/theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/rank_entry.dart';

/// 热门榜单 — 横向滚动卡片列表
class DiscoverRankRow extends StatelessWidget {
  final List<RankEntry> ranks;

  const DiscoverRankRow({super.key, required this.ranks});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: ranks.length,
        itemBuilder: (_, i) {
          final rank = ranks[i];
          return M3PressScale(
            scaleDown: 0.95,
            child: Container(
              width: 110,
              margin: const EdgeInsets.only(right: 14),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: AppShape.lg,
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: AppShape.lg,
                          child: rank.coverUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: rank.coverUrl!,
                                  width: 100,
                                  height: 100,
                                  memCacheWidth: 200,
                                  memCacheHeight: 200,
                                  fit: BoxFit.cover,
                                )
                              : Icon(Icons.leaderboard, color: cs.onSurfaceVariant),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: AppShape.lg,
                            onTap: () => Navigator.pushNamed(context, '/rank/detail',
                                arguments: {'id': rank.id, 'name': rank.name}),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rank.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

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
            child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/rank/detail',
                arguments: {'id': rank.id, 'name': rank.name}),
            child: Container(
              width: 110,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: AppShape.md,
                    child: rank.coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: rank.coverUrl!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 100,
                            height: 100,
                            color: cs.surfaceContainerHighest,
                            child: Icon(Icons.leaderboard,
                                color: cs.onSurfaceVariant),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rank.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }
}

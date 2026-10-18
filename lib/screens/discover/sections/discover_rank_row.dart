// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../../../models/rank_entry.dart';
import 'discover_media_rail.dart';

class DiscoverRankRow extends StatelessWidget {
  final List<RankEntry> ranks;

  const DiscoverRankRow({super.key, required this.ranks});

  @override
  Widget build(BuildContext context) => DiscoverMediaRail(
        compact: true,
        items: ranks
            .map((rank) => DiscoverMediaItem(
                  title: rank.name,
                  subtitle: '发现正在流行的音乐',
                  imageUrl: rank.coverUrl,
                  icon: Icons.leaderboard_rounded,
                  onTap: () => Navigator.pushNamed(context, '/rank/detail',
                      arguments: {'id': rank.id, 'name': rank.name}),
                ))
            .toList(growable: false),
      );
}

// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import 'discover_media_rail.dart';

class DiscoverIpRow extends StatelessWidget {
  final List<Map<String, dynamic>> ipList;

  const DiscoverIpRow({super.key, required this.ipList});

  @override
  Widget build(BuildContext context) => DiscoverMediaRail(
        items: ipList.map((item) {
          final name =
              item['ip_name'] as String? ?? item['name'] as String? ?? '';
          return DiscoverMediaItem(
            title: name,
            subtitle: '编辑精选',
            imageUrl:
                item['img'] as String? ?? item['sizable_cover'] as String?,
            icon: Icons.auto_awesome_rounded,
          );
        }).toList(growable: false),
      );
}

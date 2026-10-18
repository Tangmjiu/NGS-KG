// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../../../models/radio.dart';
import 'discover_media_rail.dart';

class DiscoverFmRow extends StatelessWidget {
  final List<RadioStation> fmList;

  const DiscoverFmRow({super.key, required this.fmList});

  @override
  Widget build(BuildContext context) => DiscoverMediaRail(
        compact: true,
        items: fmList
            .map((station) => DiscoverMediaItem(
                  title: station.name,
                  subtitle: '音乐电台',
                  imageUrl: station.coverUrl,
                  icon: Icons.radio_rounded,
                  onTap: () => Navigator.pushNamed(context, '/fm',
                      arguments: {'fmid': station.id, 'name': station.name}),
                ))
            .toList(growable: false),
      );
}

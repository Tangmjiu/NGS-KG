// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/player_provider.dart';
import '../foundation/app_layout.dart';
import '../foundation/app_motion.dart';

/// 内容列表为常驻播放栏预留空间，不重复计算首页导航高度。
class PlayerBottomPadding extends StatelessWidget {
  final bool showLabel;

  const PlayerBottomPadding({super.key, this.showLabel = false});

  @override
  Widget build(BuildContext context) {
    final visible = context.select<PlayerProvider, bool>((player) =>
        player.currentSong != null &&
        !player.isPlayerScreenVisible &&
        !player.isMiniPlayerDismissed);
    final playback = visible ? AppChrome.miniPlayerExtent(context) : 0.0;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text('已经到底了', style: Theme.of(context).textTheme.bodySmall),
          ),
        AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.dShort4),
          height: 24 + (playback > safeBottom ? playback : safeBottom),
        ),
      ],
    );
  }
}

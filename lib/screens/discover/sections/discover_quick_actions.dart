import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../constants/discover_constants.dart';
import '../../../models/rank_entry.dart';
import '../../../providers/player_provider.dart';
import '../../../services/music_service.dart';
import '../../../utils/logger.dart';

/// 快捷操作入口 — 4 个渐变色卡片
///
/// 排行榜 / 电台 / 每日推荐 / 新歌首发
class DiscoverQuickActions extends StatelessWidget {
  final List<RankEntry> rankList;

  const DiscoverQuickActions({super.key, required this.rankList});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (int i = 0; i < _actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              _GradientCard(
                index: i,
                action: _actions[i],
                onTap: () => _actions[i].onTap(context, rankList),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 单个快捷操作定义
class _QuickAction {
  final IconData icon;
  final String label;
  final void Function(BuildContext context, List<RankEntry> rankList) onTap;

  const _QuickAction(this.icon, this.label, {required this.onTap});
}

final _actions = [
  _QuickAction(Icons.emoji_events, '排行榜', onTap: (context, rankList) {
    if (rankList.isNotEmpty) {
      Navigator.pushNamed(context, '/rank/detail',
          arguments: {'id': rankList.first.id, 'name': rankList.first.name});
    }
  }),
  _QuickAction(Icons.radio, '电台',
      onTap: (context, _) => Navigator.pushNamed(context, '/fm')),
  _QuickAction(Icons.auto_awesome, '每日推荐', onTap: (context, _) async {
    final musicService = MusicService();
    final player = context.read<PlayerProvider>();
    try {
      final card = await musicService.getCardSongs(1);
      if (card.songs.isNotEmpty && context.mounted) {
        player.playSong(card.songs.first, playlist: card.songs);
        player.setPlayerScreenVisible(true);
        await Navigator.pushNamed(context, '/player');
        player.setPlayerScreenVisible(false);
      }
    } catch (e, s) {
      Log.e('DiscoverQuickActions', 'dailyRec error', e, s);
    }
  }),
  _QuickAction(Icons.music_note, '新歌首发', onTap: (context, _) async {
    final musicService = MusicService();
    final player = context.read<PlayerProvider>();
    try {
      final songs = await musicService.getTopSongs();
      if (songs.isNotEmpty && context.mounted) {
        player.playSong(songs.first, playlist: songs);
        player.setPlayerScreenVisible(true);
        await Navigator.pushNamed(context, '/player');
        player.setPlayerScreenVisible(false);
      }
    } catch (e, s) {
      Log.e('DiscoverQuickActions', 'newSong error', e, s);
    }
  }),
];

class _GradientCard extends StatelessWidget {
  final int index;
  final _QuickAction action;
  final VoidCallback? onTap;

  const _GradientCard({
    required this.index,
    required this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = DiscoverConstants.actionGradients[index];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(action.icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(
              action.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

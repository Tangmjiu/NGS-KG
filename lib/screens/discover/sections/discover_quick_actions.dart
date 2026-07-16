import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/rank_entry.dart';
import '../../../models/song.dart';
import '../../../providers/player_provider.dart';
import '../../../services/music_service.dart';
import '../../../utils/logger.dart';
import '../../../utils/theme.dart';
import '../../../widgets/song_tile.dart';

/// Material Design 3 Expressive 快捷操作四宫格组件
///
/// 采用 2行 × 2列 圆角方格平铺，支持动态色系匹配与手势缩放。
/// 点击每日推荐或新歌首发将展开底部精选单曲排版列表，桌面端不打断全局工作流。
class DiscoverQuickActions extends StatelessWidget {
  final List<RankEntry> rankList;

  const DiscoverQuickActions({super.key, required this.rankList});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  index: 0,
                  action: _actions[0],
                  rankList: rankList,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionTile(
                  index: 1,
                  action: _actions[1],
                  rankList: rankList,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  index: 2,
                  action: _actions[2],
                  rankList: rankList,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionTile(
                  index: 3,
                  action: _actions[3],
                  rankList: rankList,
                ),
              ),
            ],
          ),
        ],
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
  _QuickAction(Icons.emoji_events_rounded, '排行榜', onTap: (context, rankList) {
    if (rankList.isNotEmpty) {
      Navigator.pushNamed(context, '/rank/detail',
          arguments: {'id': rankList.first.id, 'name': rankList.first.name});
    }
  }),
  _QuickAction(Icons.radio_rounded, '电台',
      onTap: (context, _) => Navigator.pushNamed(context, '/fm')),
  _QuickAction(Icons.auto_awesome_rounded, '每日推荐', onTap: (context, _) async {
    final musicService = MusicService();
    try {
      final card = await musicService.getCardSongs(1);
      if (context.mounted) {
        _showSongListSheet(
          context,
          '每日推荐',
          Icons.auto_awesome_rounded,
          card.songs,
        );
      }
    } catch (e, s) {
      Log.e('DiscoverQuickActions', 'dailyRec error', e, s);
    }
  }),
  _QuickAction(Icons.music_note_rounded, '新歌首发', onTap: (context, _) async {
    final musicService = MusicService();
    try {
      final songs = await musicService.getTopSongs();
      if (context.mounted) {
        _showSongListSheet(
          context,
          '新歌首发',
          Icons.music_note_rounded,
          songs,
        );
      }
    } catch (e, s) {
      Log.e('DiscoverQuickActions', 'newSong error', e, s);
    }
  }),
];

/// 展开精选单曲排版底板 (BottomSheet)，供用户浏览或挑选播放，不强推全屏播放页
void _showSongListSheet(
    BuildContext context, String title, IconData icon, List<Song> songs) {
  showM3ModalBottomSheet(
    context: context,
    builder: (sheetContext) {
      final cs = Theme.of(sheetContext).colorScheme;
      final tt = Theme.of(sheetContext).textTheme;
      final availableHeight = MediaQuery.of(sheetContext).size.height * 0.65 -
          MediaQuery.of(sheetContext).padding.bottom;

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  Icon(icon, color: cs.primary, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (songs.isNotEmpty)
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        context
                            .read<PlayerProvider>()
                            .playSong(songs.first, playlist: songs);
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('播放全部'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (songs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text('暂无推荐列表内容',
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: availableHeight),
                child: ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (_, i) {
                    final song = songs[i];
                    return SongTile(
                      song: song,
                      onTap: (s) {
                        Navigator.pop(sheetContext);
                        context
                            .read<PlayerProvider>()
                            .playSong(s, playlist: songs);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// M3 Expressive 单个圆角方块卡片
class _ActionTile extends StatelessWidget {
  final int index;
  final _QuickAction action;
  final List<RankEntry> rankList;

  const _ActionTile({
    required this.index,
    required this.action,
    required this.rankList,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final Color cardBgColor;
    final Color iconBoxColor;
    final Color iconColor;
    final String subtitle;
    final IconData actionIcon;

    switch (index) {
      case 0:
        cardBgColor = cs.primaryContainer.withValues(alpha: 0.35);
        iconBoxColor = cs.primaryContainer;
        iconColor = cs.onPrimaryContainer;
        subtitle = '巅峰热歌 · 飙升榜';
        actionIcon = Icons.arrow_outward_rounded;
        break;
      case 1:
        cardBgColor = cs.tertiaryContainer.withValues(alpha: 0.35);
        iconBoxColor = cs.tertiaryContainer;
        iconColor = cs.onTertiaryContainer;
        subtitle = '独家调频 · 有声剧';
        actionIcon = Icons.arrow_outward_rounded;
        break;
      case 2:
        cardBgColor = cs.secondaryContainer.withValues(alpha: 0.35);
        iconBoxColor = cs.secondaryContainer;
        iconColor = cs.onSecondaryContainer;
        subtitle = '专属定制 · 随心播';
        actionIcon = Icons.play_arrow_rounded;
        break;
      case 3:
      default:
        cardBgColor = cs.surfaceContainerHighest.withValues(alpha: 0.65);
        iconBoxColor = cs.secondary.withValues(alpha: 0.15);
        iconColor = cs.secondary;
        subtitle = '重磅首发 · 尝鲜听';
        actionIcon = Icons.play_arrow_rounded;
        break;
    }

    return M3PressScale(
      child: Material(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => action.onTap(context, rankList),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 114,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: iconBoxColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(action.icon, color: iconColor, size: 24),
                    ),
                    Icon(
                      actionIcon,
                      size: 18,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ],
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        action.label,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

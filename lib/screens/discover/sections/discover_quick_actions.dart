// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/rank_entry.dart';
import '../../../models/song.dart';
import '../../../providers/player_provider.dart';
import '../../../services/music_service.dart';
import '../../../utils/logger.dart';
import '../../../ui/app_ui.dart';
import '../../../ui/components/song_tile.dart';

/// Material Design 3 Expressive 快捷操作四宫格组件
///
/// 采用 2行 × 2列 圆角方格平铺，支持动态色系匹配与手势缩放。
/// 点击每日推荐或新歌首发将展开底部精选单曲排版列表，桌面端不打断全局工作流。
class DiscoverQuickActions extends StatelessWidget {
  final List<RankEntry> rankList;

  const DiscoverQuickActions({super.key, required this.rankList});

  @override
  Widget build(BuildContext context) {
    final inset = AppThemeTokens.of(context).pagePadding;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 680 ? 4 : 2;
        final tileWidth = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(
              _actions.length,
              (index) => SizedBox(
                    width: tileWidth,
                    child: _ActionTile(
                      index: index,
                      action: _actions[index],
                      rankList: rankList,
                    ),
                  )),
        );
      }),
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
  showAppBottomSheet(
    context: context,
    builder: (sheetContext) {
      final cs = Theme.of(sheetContext).colorScheme;
      final tt = Theme.of(sheetContext).textTheme;
      final screenHeight = MediaQuery.of(sheetContext).size.height;
      final bottomPadding = MediaQuery.of(sheetContext).padding.bottom;

      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.7,
        ),
        child: SafeArea(
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
                        style: tt.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
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
                        style: tt.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ),
                )
              else
                // 使用 Flexible 代替原来的硬编高计算，结合 ListView 内部 bottom padding，完美实现滑到底部且永不溢出
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.only(
                      bottom: bottomPadding > 0 ? bottomPadding + 20 : 32,
                    ),
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
        ),
      );
    },
  );
}

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
    final colors = [
      cs.primaryContainer,
      cs.secondaryContainer,
      cs.tertiaryContainer,
      cs.surfaceContainerHigh,
    ];
    return AppShortcutCard(
      icon: action.icon,
      title: action.label,
      color: colors[index],
      onTap: () => action.onTap(context, rankList),
    );
  }
}

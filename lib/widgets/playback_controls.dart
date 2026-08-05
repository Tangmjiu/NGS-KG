import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../utils/theme.dart';
import 'playlist_queue_panel.dart';

class PlaybackControls extends StatelessWidget {
  const PlaybackControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (_, player, __) {
        final cs = Theme.of(context).colorScheme;
        return LayoutBuilder(
          builder: (_, constraints) {
            final isWide = constraints.maxWidth > 400;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                M3PressScale(
                  child: IconButton(
                    icon: Icon(_modeIcon(player.playMode), size: 24),
                    tooltip: '播放模式',
                    color: cs.onSurfaceVariant,
                    onPressed: _modeCycle(player),
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
                SizedBox(width: isWide ? 16 : 8),
                M3PressScale(
                  child: IconButton(
                    icon: Icon(
                      player.isFmMode
                          ? Icons.heart_broken_outlined
                          : Icons.skip_previous_rounded,
                      size: 36,
                    ),
                    tooltip: player.isFmMode ? '不喜欢' : '上一首',
                    color: cs.onSurface,
                    onPressed: player.playPrevious,
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor:
                          cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                SizedBox(width: isWide ? 24 : 16),
                M3PressScale(
                  scaleDown: 0.92, // 更强烈的按压下沉反馈
                  child: AnimatedContainer(
                    duration: AppMotion.dShort4,
                    curve: AppMotion.emphasized,
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius:
                          BorderRadius.circular(player.isPlaying ? 28 : 44),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: player.togglePlayPause,
                        borderRadius:
                            BorderRadius.circular(player.isPlaying ? 28 : 44),
                        child: AnimatedSwitcher(
                          duration: AppMotion.dShort4,
                          switchInCurve: AppMotion.emphasizedDecelerate,
                          switchOutCurve: AppMotion.emphasizedAccelerate,
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                  opacity: animation, child: child),
                            );
                          },
                          child: Icon(
                            key: ValueKey(player.isPlaying),
                            player.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 40,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isWide ? 24 : 16),
                M3PressScale(
                  child: IconButton(
                    icon: const Icon(Icons.skip_next_rounded, size: 36),
                    tooltip: '下一首',
                    color: cs.onSurface,
                    onPressed: player.playNext,
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor:
                          cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                SizedBox(width: isWide ? 16 : 8),
                M3PressScale(
                  child: IconButton(
                    icon: const Icon(Icons.playlist_play_rounded, size: 24),
                    tooltip: '播放列表',
                    color: cs.onSurfaceVariant,
                    onPressed: () => showPlaylistStatic(context, player),
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _modeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.shuffle:
        return Icons.shuffle;
      case PlayMode.repeatOne:
        return Icons.repeat_one;
      case PlayMode.radio:
        return Icons.radio;
      default:
        return Icons.repeat;
    }
  }

  VoidCallback _modeCycle(PlayerProvider player) {
    return () {
      const modes = [PlayMode.sequential, PlayMode.shuffle, PlayMode.repeatOne];
      final next = modes[(modes.indexOf(player.playMode) + 1) % modes.length];
      player.setPlayMode(next);
    };
  }

  /// 弹出播放队列（移动端底部弹窗形式；桌面端使用常驻侧栏，见 DesktopShell）
  static void showPlaylistStatic(BuildContext context, PlayerProvider player) {
    showM3ModalBottomSheet(
      context: context,
      // root Navigator：桌面端自建 Shell Navigator 的弹窗层不可靠，
      // root Overlay 位于 AppShell 内部，可见性有保证
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollCtrl) => SafeArea(
          child: PlaylistQueuePanel(
            player: player,
            dismissOnSelect: true,
            scrollController: scrollCtrl,
          ),
        ),
      ),
    );
  }
}

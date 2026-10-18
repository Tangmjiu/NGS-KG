// SPDX-License-Identifier: MIT
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../screens/player_screen.dart';
import 'cover_art.dart';
import '../foundation/app_layout.dart';

/// 常驻播放控制；进度、按钮状态与歌曲信息分别订阅。
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> with WidgetsBindingObserver {
  bool _foreground = true;
  bool _systemReduceMotion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    _systemReduceMotion = features.disableAnimations || features.reduceMotion;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _foreground = state == AppLifecycleState.resumed);
  }

  @override
  void didChangeAccessibilityFeatures() {
    setState(() {
      final features =
          WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
      _systemReduceMotion = features.disableAnimations || features.reduceMotion;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        !_systemReduceMotion;
    return Selector<PlayerProvider,
        ({Song? song, bool visible, bool dismissed})>(
      selector: (_, player) => (
        song: player.currentSong,
        visible: player.isPlayerScreenVisible,
        dismissed: player.isMiniPlayerDismissed,
      ),
      builder: (context, state, _) {
        final song = state.song;
        if (song == null || state.visible || state.dismissed) {
          return const SizedBox.shrink();
        }
        final colors = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Dismissible(
            key: ValueKey('mini_${song.hash ?? song.id}'),
            direction: DismissDirection.horizontal,
            movementDuration:
                animate ? const Duration(milliseconds: 200) : Duration.zero,
            confirmDismiss: (direction) async {
              final player = context.read<PlayerProvider>();
              if (direction == DismissDirection.endToStart) {
                player.playNext();
              } else {
                player.playPrevious();
              }
              return false;
            },
            child: Material(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                excludeFromSemantics: true,
                onTap: PlayerScreen.open,
                onLongPress: () => _hide(context),
                child: SizedBox(
                  height: AppChrome.miniPlayerExtent(context) - 12,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Semantics(
                                button: true,
                                label: '打开播放器',
                                value: '${song.name} · ${song.artistDisplay}',
                                hint: '长按隐藏播放栏',
                                onTap: PlayerScreen.open,
                                onLongPress: () => _hide(context),
                                child: ExcludeSemantics(
                                  child: Row(
                                    children: [
                                      CoverArt(
                                        url: song.thumbnailCoverUrl,
                                        coverData: song.coverData,
                                        size: 46,
                                        borderRadius: 16,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              song.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                height: 1.2,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    colors.onSecondaryContainer,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              song.artistDisplay,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                height: 1.2,
                                                color: colors
                                                    .onSecondaryContainer
                                                    .withValues(alpha: 0.75),
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
                            const SizedBox(width: 6),
                            _PlaybackButton(animate: animate),
                            IconButton(
                              tooltip: '下一首',
                              constraints: const BoxConstraints(
                                  minWidth: 48, minHeight: 48),
                              visualDensity: VisualDensity.standard,
                              onPressed:
                                  context.read<PlayerProvider>().playNext,
                              icon: const Icon(Icons.skip_next_rounded),
                              color: colors.onSecondaryContainer,
                            ),
                          ],
                        ),
                      ),
                      const Positioned(
                        bottom: 0,
                        left: 16,
                        right: 16,
                        child: _PlaybackProgress(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _hide(BuildContext context) {
    final player = context.read<PlayerProvider>();
    player.dismissMiniPlayer();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('播放栏已隐藏，播放新歌时会重新显示'),
      action: SnackBarAction(label: '恢复', onPressed: player.showMiniPlayer),
    ));
  }
}

class _PlaybackButton extends StatelessWidget {
  final bool animate;
  const _PlaybackButton({required this.animate});

  @override
  Widget build(BuildContext context) =>
      Selector<PlayerProvider, ({bool playing, bool loading})>(
        selector: (_, player) => (
          playing: player.isPlaying,
          loading: player.isLoading,
        ),
        builder: (context, state, _) => MergeSemantics(
          child: Semantics(
            value: state.loading ? '正在加载' : null,
            child: IconButton.filled(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              visualDensity: VisualDensity.standard,
              tooltip: state.playing ? '暂停' : '播放',
              onPressed: context.read<PlayerProvider>().togglePlayPause,
              icon: state.loading
                  ? SizedBox.square(
                      dimension: 22,
                      child: animate
                          ? CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            )
                          : const Icon(Icons.hourglass_top_rounded, size: 22),
                    )
                  : Icon(state.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded),
            ),
          ),
        ),
      );
}

class _PlaybackProgress extends StatelessWidget {
  const _PlaybackProgress();

  @override
  Widget build(BuildContext context) {
    final progress =
        context.select<PlayerProvider, ValueListenable<PlaybackProgress>>(
            (player) => player.playbackProgress);
    return ValueListenableBuilder<PlaybackProgress>(
      valueListenable: progress,
      builder: (context, value, _) {
        final duration = value.duration.inMilliseconds;
        if (duration <= 0) return const SizedBox.shrink();
        return LinearProgressIndicator(
          value: (value.position.inMilliseconds / duration).clamp(0.0, 1.0),
          minHeight: 2,
          backgroundColor: Colors.transparent,
          color: Theme.of(context).colorScheme.primary,
        );
      },
    );
  }
}

// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wearable_rotary/wearable_rotary.dart';

import '../../models/song.dart';
import '../../providers/liked_songs_provider.dart';
import '../../providers/player_provider.dart';
import '../screens/queue_screen.dart';
import '../utils/watch_motion.dart';
import 'watch_album_backdrop.dart';
import 'watch_like_button.dart';
import 'watch_player_primitives.dart';
import 'watch_transport_face.dart';

class WatchQuickPanel extends StatefulWidget {
  const WatchQuickPanel({super.key, required this.onClose});
  final VoidCallback onClose;

  static Future<void> show(BuildContext context) {
    WatchMotion.heavy();
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭快捷面板',
      barrierColor: Colors.black,
      transitionDuration: Duration.zero,
      pageBuilder: (context, _, _) =>
          WatchQuickPanel(onClose: () => Navigator.of(context).pop()),
    );
  }

  @override
  State<WatchQuickPanel> createState() => _WatchQuickPanelState();
}

class _WatchQuickPanelState extends State<WatchQuickPanel> {
  final ScrollController _scroll = RotaryScrollController();
  double? _dismissStart;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;
    final tone = player.palette?.dominant ?? const Color(0xff91839f);
    final mode = player.playMode;
    final modeLabel = switch (mode) {
      PlayMode.shuffle => '随机播放',
      PlayMode.repeatOne => '单曲循环',
      PlayMode.radio => '电台播放',
      _ => '顺序播放',
    };
    final next = _upNext(player);
    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          WatchPlaybackBackdrop(art: song?.albumCoverUrl, tone: tone),
          GestureDetector(
            onTap: widget.onClose,
            behavior: HitTestBehavior.opaque,
          ),
          WatchPlayerInsets(
            child: WatchSpringReveal(
              child: Listener(
                onPointerDown: (event) {
                  _dismissStart = _scroll.hasClients && _scroll.offset <= 0
                      ? event.position.dy
                      : null;
                },
                onPointerCancel: (_) => _dismissStart = null,
                onPointerUp: (event) {
                  final start = _dismissStart;
                  _dismissStart = null;
                  if (start != null &&
                      event.position.dy - start > 44 &&
                      ModalRoute.of(context)?.isCurrent == true) {
                    widget.onClose();
                  }
                },
                child: ListView(
                  controller: _scroll,
                  padding: EdgeInsets.zero,
                  children: [
                    Text(
                      song?.name ?? '暂无播放',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (song != null)
                      Text(
                        song.artistDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      children: [
                        if (!player.isFmMode)
                          _button(
                            switch (mode) {
                              PlayMode.shuffle => Icons.shuffle_rounded,
                              PlayMode.repeatOne => Icons.repeat_one_rounded,
                              _ => Icons.repeat_rounded,
                            },
                            '播放模式：$modeLabel',
                            song == null
                                ? null
                                : () => player.setPlayMode(switch (mode) {
                                    PlayMode.sequential => PlayMode.shuffle,
                                    PlayMode.shuffle => PlayMode.repeatOne,
                                    _ => PlayMode.sequential,
                                  }),
                          ),
                        if (song != null)
                          Selector<LikedSongsProvider, bool>(
                            selector: (_, likes) =>
                                likes.likedIds.contains(song.id),
                            builder: (_, liked, child) => Tooltip(
                              message: liked ? '取消收藏' : '收藏',
                              child: child!,
                            ),
                            child: SizedBox.square(
                              dimension: 48,
                              child: WatchLikeButton(song: song, size: 23),
                            ),
                          ),
                        _button(
                          player.isPlaying
                              ? Icons.pause_circle_outline_rounded
                              : Icons.play_circle_outline_rounded,
                          player.isPlaying ? '暂停' : '播放',
                          song == null ? null : player.togglePlayPause,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Material(
                      color: Colors.transparent,
                      shape: const StadiumBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: WatchAlbumBackdrop(
                              art: next?.albumCoverUrl,
                              tone: tone,
                            ),
                          ),
                          Positioned.fill(
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: .32),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const WatchQueueScreen(),
                                ),
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              next == null ? '播放队列' : '下一首',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 10,
                                              ),
                                            ),
                                            Text(
                                              next?.name ??
                                                  '${player.playlist.length} 首歌曲',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: Colors.white70,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      children: [
                        _button(
                          player.isFmMode
                              ? Icons.thumb_down_outlined
                              : Icons.skip_previous_rounded,
                          player.isFmMode ? '不喜欢，跳过' : '上一首',
                          song == null ? null : player.playPrevious,
                        ),
                        _button(Icons.close_rounded, '关闭快捷面板', widget.onClose),
                        _button(
                          Icons.skip_next_rounded,
                          '下一首',
                          song == null ? null : player.playNext,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Shuffle order and the next batch of FM recommendations are private to the
  // playback engine. Show the actual queue instead of guessing the next track.
  Song? _upNext(PlayerProvider player) {
    final queue = player.playlist;
    if (queue.isEmpty || player.playMode == PlayMode.shuffle) return null;
    if (player.playMode == PlayMode.repeatOne) return player.currentSong;
    final index = player.currentIndex + 1;
    if (index >= 0 && index < queue.length) return queue[index];
    return player.playlistEndProvider == null ? queue.first : null;
  }

  Widget _button(IconData icon, String label, VoidCallback? action) {
    return SizedBox.square(
      dimension: 48,
      child: IconButton(
        tooltip: label,
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 24),
        color: Colors.white,
        onPressed: action == null
            ? null
            : () {
                WatchMotion.tap();
                action();
              },
      ),
    );
  }
}

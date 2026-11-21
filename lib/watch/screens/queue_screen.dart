// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wearable_rotary/wearable_rotary.dart';

import '../../providers/player_provider.dart';
import '../widgets/watch_player_primitives.dart';
import '../widgets/watch_scaffold.dart';
import '../widgets/watch_song_tile.dart';
import '../widgets/watch_transport_face.dart';

class WatchQueueScreen extends StatefulWidget {
  const WatchQueueScreen({super.key});

  @override
  State<WatchQueueScreen> createState() => _WatchQueueScreenState();
}

class _WatchQueueScreenState extends State<WatchQueueScreen> {
  final ScrollController _scroll = RotaryScrollController();
  int? _lastIndex;
  double? _lastExtent;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _trackCurrent(int index, double extent) {
    if (_lastIndex == index && _lastExtent == extent) return;
    final first = _lastIndex == null;
    _lastIndex = index;
    _lastExtent = extent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index != _lastIndex || !_scroll.hasClients || index < 0) {
        return;
      }
      final pos = _scroll.position;
      if (!first && pos.isScrollingNotifier.value) return;
      final offset = (index * extent).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      );
      if (first || MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(offset);
      } else {
        _scroll.animateTo(
          offset,
          duration: const Duration(milliseconds: 230),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final songs = player.playlist;
    final song = player.currentSong;
    final index = player.currentIndex;
    final extent =
        56.0 +
        (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(0.0, 100.0) *
            2.7;
    if (songs.isEmpty) {
      _lastIndex = null;
      return const WatchScaffold(
        showTime: false,
        body: WatchPlayerInsets(child: Center(child: Text('播放队列为空'))),
      );
    }
    _trackCurrent(index, extent);
    return WatchScaffold(
      showTime: false,
      scrollController: _scroll,
      body: Stack(
        fit: StackFit.expand,
        children: [
          WatchPlaybackBackdrop(
            art: song?.albumCoverUrl,
            tone: player.palette?.dominant ?? const Color(0xffbe969c),
          ),
          WatchPlayerInsets(
            child: Column(
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    song?.name ?? '播放队列',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  [
                    if (song?.artistDisplay.isNotEmpty == true)
                      song!.artistDisplay,
                    '${songs.length} 首',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: EdgeInsets.zero,
                    itemExtent: extent,
                    itemCount: songs.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Semantics(
                        selected: i == index,
                        child: WatchSongTile.fromSong(
                          song: songs[i],
                          isPlaying: i == index,
                          onTap: () => player.playIndex(i),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

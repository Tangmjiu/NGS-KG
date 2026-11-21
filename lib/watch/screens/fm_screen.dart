// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../models/song_mapper.dart';
import '../../providers/player_provider.dart';
import '../../services/music_service.dart';
import '../../utils/logger.dart';
import '../widgets/watch_player_primitives.dart';
import '../widgets/watch_scaffold.dart';
import '../widgets/watch_transport_face.dart';
import 'player_screen.dart';

class WatchFmScreen extends StatefulWidget {
  const WatchFmScreen({super.key});

  @override
  State<WatchFmScreen> createState() => _WatchFmScreenState();
}

class _WatchFmScreenState extends State<WatchFmScreen> {
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    final player = context.read<PlayerProvider>();
    if (player.isFmMode && player.currentSong != null) {
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    final service = context.read<MusicService>();
    final player = context.read<PlayerProvider>();
    try {
      final raw = await service.getPersonalFm();
      final songs = raw.map(SongMapper.fromFmJson).whereType<Song>().toList();
      if (!mounted) return;
      if (songs.isEmpty) {
        setState(() {
          _message = '暂时没有推荐歌曲';
          _loading = false;
        });
        return;
      }
      // These callbacks belong to the queue, which outlives this route.
      player.startFmPlaylist(
        songs,
        bufferProvider: () => _more(service, player),
        onDislike: () => unawaited(_dislike(service, player)),
      );
      setState(() => _loading = false);
    } catch (error, stack) {
      Log.e('WatchFmScreen', 'load error', error, stack);
      if (!mounted) return;
      setState(() {
        _message = '电台加载失败';
        _loading = false;
      });
    }
  }

  static Future<List<Song>> _more(
    MusicService service,
    PlayerProvider player,
  ) async {
    final last = player.playlist.lastOrNull;
    try {
      final raw = await service.getPersonalFm(
        hash: last?.hash,
        songid: last?.mixSongId ?? last?.id,
        action: 'play',
      );
      return raw.map(SongMapper.fromFmJson).whereType<Song>().toList();
    } catch (error, stack) {
      Log.e('WatchFmScreen', 'fetch more error', error, stack);
      return [];
    }
  }

  static Future<void> _dislike(
    MusicService service,
    PlayerProvider player,
  ) async {
    final song = player.currentSong;
    if (song == null) return;
    try {
      await service.getPersonalFm(
        hash: song.hash,
        songid: song.mixSongId ?? song.id,
        action: 'garbage',
        playtime: player.position.inSeconds,
      );
    } catch (error, stack) {
      Log.e('WatchFmScreen', 'dislike feedback failed', error, stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _message == null) return const WatchPlayerScreen();
    return WatchScaffold(
      showTime: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const WatchPlaybackBackdrop(tone: Color(0xff81a6a6)),
          WatchPlayerInsets(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.radio_rounded,
                      size: 28,
                      color: Color(0xffbfdad9),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '私人 FM',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _message ?? '正在加载歌曲',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    if (!_loading)
                      TextButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('重试'),
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
}

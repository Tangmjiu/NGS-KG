// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../models/song_mapper.dart';
import '../ui/app_ui.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../ui/components/song_tile.dart';
import '../ui/components/player_bottom_padding.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final MusicService _musicService = MusicService();
  List<Song> _songs = [];
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loadFailed = false;
      _isLoading = _songs.isEmpty;
    });
    try {
      final raw = await _musicService.getUserHistory();
      if (mounted) {
        setState(() {
          _songs = raw
              .map((e) => SongMapper.fromTrackJson(e))
              .whereType<Song>()
              .map((s) => Song(
                    id: s.id,
                    name: s.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
                    artists: s.artists,
                    albumName: s.albumName,
                    albumCoverUrl: s.albumCoverUrl,
                    duration: s.duration,
                    lyricUrl: s.lyricUrl,
                    filePath: s.filePath,
                    hash: s.hash,
                    qualities: s.qualities,
                    albumId: s.albumId,
                    fileId: s.fileId,
                    lyrics: s.lyrics,
                  ))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e, s) {
      Log.e('history_screen', 'error', e, s);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('听歌历史')),
        body: AppPageBody(
            child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                  child: AppPageHeader(
                title: '最近听过',
                subtitle: _songs.isEmpty
                    ? '音乐留下的足迹，随时回来重听。'
                    : '共 ${_songs.length} 首 · 找回刚刚听过的好歌',
              )),
              if (_isLoading)
                const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: AppLoadingIndicator()))
              else if (_songs.isEmpty)
                SliverToBoxAdapter(
                    child: AppEmptyState(
                  icon: _loadFailed
                      ? Icons.cloud_off_rounded
                      : Icons.history_rounded,
                  title: _loadFailed ? '历史记录暂时无法加载' : '还没有听歌记录',
                  message:
                      _loadFailed ? '下拉重新加载，或稍后再试。' : '开始播放后，你的听歌足迹会出现在这里。',
                  action: _loadFailed
                      ? FilledButton.tonalIcon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('重试'))
                      : null,
                ))
              else
                SliverList(
                    delegate: SliverChildBuilderDelegate(
                  (context, index) => SongTile(
                      song: _songs[index],
                      onTap: (song) => context
                          .read<PlayerProvider>()
                          .playSong(song, playlist: _songs)),
                  childCount: _songs.length,
                )),
              const SliverToBoxAdapter(
                  child: PlayerBottomPadding(showLabel: false)),
            ],
          ),
        )),
      );
}

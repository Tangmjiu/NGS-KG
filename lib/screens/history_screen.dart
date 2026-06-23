import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../utils/responsive.dart';
import '../widgets/song_tile.dart';
import '../widgets/desktop_route_wrapper.dart';
import '../widgets/desktop_song_table.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final MusicService _musicService = MusicService();
  List<Song> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _musicService.getUserHistory();
      if (mounted) {
        setState(() {
          _songs = raw
              .map((e) => Song.fromTrackJson(e))
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 取第一首歌的封面作为背景
  String? get _bgCover =>
      _songs.isNotEmpty ? _songs.first.albumCoverUrl : null;

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      desktop: (_) => _buildDesktop(),
      mobile: (_) => _buildMobile(),
      tablet: (_) => _buildMobile(),
    );
  }

  Widget _buildDesktop() {
    return DesktopRouteWrapper(
      title: '播放历史',
      actions: [
        if (_songs.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: '清空历史',
            onPressed: _clearHistory,
          ),
      ],
      child: DesktopSongTable(
        songs: _songs,
        isLoading: _isLoading,
        emptyMessage: '暂无听歌历史',
        currentSongId: context.watch<PlayerProvider>().currentSong?.id,
      ),
    );
  }

  Widget _buildMobile() {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: null,
      appBar: AppBar(
        title: const Text('听歌历史'),
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: _buildMobileBody(cs),
    );
  }

  Widget _buildMobileBody(ColorScheme cs) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('暂无听歌历史',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: _buildBackground(cs),
        ),
        RefreshIndicator(
          onRefresh: _load,
          color: cs.onSurface,
          child: ListView.builder(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 80,
              bottom: 24,
            ),
            itemCount: _songs.length,
            itemBuilder: (_, i) => SongTile(
              song: _songs[i],
              onTap: (s) => context
                  .read<PlayerProvider>()
                  .playSong(s, playlist: _songs),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定要清空所有听歌历史吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _songs = []);
    }
  }

  Widget _buildBackground(ColorScheme cs) {
    final cover = _bgCover;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 基底色
        Container(color: cs.surface),
        // 模糊的专辑封面
        if (cover != null)
          CachedNetworkImage(
            imageUrl: cover.replaceAll('{size}', '480'),
            fit: BoxFit.cover,
            imageBuilder: (_, provider) => ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Image(image: provider, fit: BoxFit.cover),
            ),
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
            placeholder: (_, __) => const SizedBox.shrink(),
          ),
        // 从左到右渐变遮罩：左清晰→右暗色
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                cs.scrim.withValues(alpha: 0.85),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        // 底部轻微暗化，让列表文字更清楚
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                cs.scrim.withValues(alpha: 0.4),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ],
    );
  }
}

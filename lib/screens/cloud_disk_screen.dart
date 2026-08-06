import 'package:flutter/material.dart';
import '../utils/app_icons.dart';
import '../utils/theme.dart';
import 'package:provider/provider.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '../models/song.dart';
import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import '../utils/logger.dart';
import '../services/music_service.dart';

class CloudDiskScreen extends StatefulWidget {
  const CloudDiskScreen({super.key});

  @override
  State<CloudDiskScreen> createState() => _CloudDiskScreenState();
}

class _CloudDiskScreenState extends State<CloudDiskScreen> {
  final MusicService _musicService = MusicService();
  List<Map<String, dynamic>> _songs = [];
  bool _isLoading = true;
  int? _playingIndex;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final songs = await _musicService.getUserCloudDisk();
      if (mounted) setState(() { _songs = songs; _error = null; });
    } catch (e, s) {
      Log.e('CloudDisk', 'load error', e, s);
      if (mounted) setState(() => _error = '加载失败，请下拉刷新重试');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _playSong(int index, Map<String, dynamic> item) async {
    setState(() => _playingIndex = index);
    final hash = item['hash'] as String?;
    if (hash == null) { setState(() => _playingIndex = null); return; }
    try {
      final url = await _musicService.getCloudSongUrl(
        hash,
        albumId: item['album_id'] as int?,
        name: item['name'] as String?,
        albumAudioId: item['album_audio_id'] as int?,
      );
      if (!mounted) { return; }
      if (url.isEmpty) {
        if (mounted) { setState(() => _playingIndex = null); }
        return;
      }
      final song = Song(
        id: hash.hashCode,
        name: item['name'] as String? ?? '',
        artists: [item['author_name'] as String? ?? ''],
        albumName: item['album_name'] as String?,
        albumCoverUrl: item['cover'] as String?,
        duration: ((item['timelength'] as int?) ?? 0) ~/ 1000,
        hash: hash,
        mixSongId: int.tryParse(item['mixsongid']?.toString() ?? ''),
        qualities: hash.isNotEmpty ? {'128': hash} : null,
        filePath: url,
      );
      if (!mounted) { return; }
      await context.read<PlayerProvider>().playSong(song);
    } catch (e, s) {
      Log.e('CloudDisk', 'play error', e, s);
    }
    if (mounted) setState(() => _playingIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 880;
    final bodyContent = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon(Symbols.error_outline_rounded, size: 80, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                ),
              )
            : _songs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIcon(Symbols.cloud_off_rounded, size: 80, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text('云盘暂无歌曲', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: _songs.length,
                  itemBuilder: (_, i) {
                    final item = _songs[i];
                    final name = item['name'] as String? ?? '';
                    final author = item['author_name'] as String? ?? '';
                    final isPlaying = _playingIndex == i;
                    return ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: AppShape.sm,
                        ),
                        child: isPlaying
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : AppIcon(Symbols.cloud_done_rounded, color: Theme.of(context).colorScheme.primary),
                      ),
                      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(author, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      enabled: !isPlaying,
                      onTap: isPlaying ? null : () => _playSong(i, item),
                    );
                  },
                ),
              );
    return Scaffold(
      appBar: AppBar(title: const Text('云盘')),
      body: isWide
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: bodyContent,
              ),
            )
          : bodyContent,
    );
  }
}

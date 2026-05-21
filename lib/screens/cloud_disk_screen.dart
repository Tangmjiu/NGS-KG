import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final songs = await _musicService.getUserCloudDisk();
      if (mounted) setState(() => _songs = songs);
    } catch (e, s) {
      Log.e('CloudDisk', 'load error', e, s);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _playSong(int index, Map<String, dynamic> item) async {
    setState(() => _playingIndex = index);
    final hash = item['hash'] as String?;
    if (hash == null) { setState(() => _playingIndex = null); return; }
    try {
      final url = await _musicService.getCloudSongUrl(hash);
      if (!mounted) { return; }
      if (url.isEmpty) {
        if (mounted) { setState(() => _playingIndex = null); }
        return;
      }
      final song = Song(
        id: hash.hashCode,
        name: item['name'] as String? ?? '',
        artists: [item['author_name'] as String? ?? ''],
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
    return Scaffold(
      appBar: AppBar(title: const Text('云盘')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _songs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 80, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: isPlaying
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(Icons.cloud_done, color: Theme.of(context).colorScheme.primary),
                        ),
                        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(author, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        enabled: !isPlaying,
                        onTap: isPlaying ? null : () => _playSong(i, item),
                      );
                    },
                  ),
                ),
    );
  }
}

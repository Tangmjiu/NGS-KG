import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../widgets/song_tile.dart';

class CloudDiskScreen extends StatefulWidget {
  const CloudDiskScreen({super.key});

  @override
  State<CloudDiskScreen> createState() => _CloudDiskScreenState();
}

class _CloudDiskScreenState extends State<CloudDiskScreen> {
  final MusicService _musicService = MusicService();
  List<Map<String, dynamic>> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final songs = await _musicService.getUserCloudDisk();
      if (mounted) setState(() => _songs = songs);
    } catch (e) {
      debugPrint('[CloudDisk] load error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _playSong(Map<String, dynamic> item) async {
    final hash = item['hash'] as String?;
    if (hash == null) return;
    try {
      final url = await _musicService.getCloudSongUrl(hash);
      if (url.isEmpty) return;
      if (!mounted) return;
      final song = Song(
        id: hash.hashCode,
        name: item['name'] as String? ?? '',
        artists: [item['author_name'] as String? ?? ''],
        filePath: url,
      );
      context.read<PlayerProvider>().playSong(song);
    } catch (e) {
      debugPrint('[CloudDisk] play error: $e');
    }
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
                      Icon(Icons.cloud_off, size: 80, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text('云盘暂无歌曲',
                          style: TextStyle(color: Colors.grey[400])),
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
                      return ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.cloud_done, color: Colors.blue),
                        ),
                        title: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(author,
                            style: TextStyle(color: Colors.grey[400])),
                        onTap: () => _playSong(item),
                      );
                    },
                  ),
                ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
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
                      Text('云盘暂无歌曲', style: TextStyle(color: Colors.grey[400])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: _songs.length,
                    itemBuilder: (_, i) {
                      final s = _songs[i];
                      return ListTile(
                        leading: const Icon(Icons.cloud_done),
                        title: Text(s['name'] as String? ?? ''),
                        subtitle: Text(s['author'] as String? ?? '',
                            style: TextStyle(color: Colors.grey[400])),
                        onTap: () {},
                      );
                    },
                  ),
                ),
    );
  }
}

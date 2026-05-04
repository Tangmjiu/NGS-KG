import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/local_song.dart';
import '../services/local_music_service.dart';
import '../providers/player_provider.dart';
import '../models/song.dart';

class LocalMusicScreen extends StatefulWidget {
  const LocalMusicScreen({super.key});

  @override
  State<LocalMusicScreen> createState() => _LocalMusicScreenState();
}

class _LocalMusicScreenState extends State<LocalMusicScreen> {
  final LocalMusicService _service = LocalMusicService();
  List<LocalSong> _songs = [];
  bool _isScanning = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _status = '正在扫描...';
    });
    try {
      final songs = await _service.scanMusic();
      if (mounted) {
        setState(() {
          _songs = songs;
          _isScanning = false;
          _status = _songs.isEmpty ? '未找到本地音乐' : '找到 ${_songs.length} 首';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _status = '扫描失败';
        });
      }
    }
  }

  void _playSong(LocalSong localSong) {
    final song = Song(
      id: localSong.filePath.hashCode,
      name: localSong.displayName,
      artists: localSong.artist != null ? [localSong.artist!] : ['本地音乐'],
      albumName: localSong.album,
    );
    final playlist = _songs.map((s) => Song(
      id: s.filePath.hashCode,
      name: s.displayName,
      artists: s.artist != null ? [s.artist!] : ['本地音乐'],
      albumName: s.album,
    )).toList();
    context.read<PlayerProvider>().playSong(song, playlist: playlist);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('本地音乐'),
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _startScan,
            ),
        ],
      ),
      body: _isScanning
          ? const Center(child: CircularProgressIndicator())
          : _songs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_note, size: 80, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text(_status, style: TextStyle(color: Colors.grey[400])),
                      const SizedBox(height: 24),
                      FilledButton.tonal(
                        onPressed: _startScan,
                        child: const Text('重新扫描'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_status,
                          style: TextStyle(color: Colors.grey[400])),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _songs.length,
                        itemBuilder: (_, i) {
                          final s = _songs[i];
                          return ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.audiotrack),
                            ),
                            title: Text(s.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              s.artist ?? '未知歌手',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                            onTap: () => _playSong(s),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

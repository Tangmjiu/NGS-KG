import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/local_song.dart';
import '../services/local_music_service.dart';
import '../providers/player_provider.dart';
import '../utils/logger.dart';
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
  bool _permissionDenied = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    final status = await Permission.audio.status;
    if (!status.isGranted) {
      final result = await Permission.audio.request();
      if (!result.isGranted && mounted) {
        setState(() => _permissionDenied = true);
        return;
      }
    }
    _permissionDenied = false;
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
    } catch (e, s) { Log.e('local_music_screen', 'error', e, s);
      if (mounted) {
        setState(() {
          _isScanning = false;
          _status = '扫描失败';
        });
      }
    }
  }

  Map<String, String> _buildQualityMap(LocalSong s) {
    final q = <String, String>{};
    if (s.codec == 'FLAC' || s.codec == 'WAV') {
      q['flac'] = s.filePath;
    } else if (s.bitrate != null && s.bitrate! >= 320) {
      q['320'] = s.filePath;
    } else {
      q['128'] = s.filePath;
    }
    return q;
  }

  Song _localSongToSong(LocalSong s) {
    return Song(
      id: s.filePath.hashCode,
      name: s.displayName,
      artists: [s.artist ?? '本地音乐'],
      albumName: s.album,
      albumCoverUrl: s.albumCoverPath != null
          ? 'file://${s.albumCoverPath}'
          : null,
      filePath: s.filePath,
      duration: s.duration,
      qualities: s.bitrate != null ? _buildQualityMap(s) : null,
      lyrics: s.lyrics,
    );
  }

  void _playSong(LocalSong localSong) {
    final song = _localSongToSong(localSong);
    final playlist = _songs.map(_localSongToSong).toList();
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
              tooltip: '重新扫描',
              onPressed: _startScan,
            ),
        ],
      ),
      body: _permissionDenied
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 80, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  const Text('需要存储权限才能扫描本地音乐'),
                  const SizedBox(height: 24),
                  FilledButton.tonal(
                    onPressed: openAppSettings,
                    child: const Text('去设置开启'),
                  ),
                ],
              ),
            )
          : _isScanning
          ? const Center(child: CircularProgressIndicator())
          : _songs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_note, size: 80, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text(_status, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.audiotrack),
                            ),
                            title: Text(s.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              (s.artist ?? '未知歌手') + (s.codec != null ? ' · ${s.codec}' : '') + (s.bitrate != null ? ' ${s.bitrate}kbps' : ''),
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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

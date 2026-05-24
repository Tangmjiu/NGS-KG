import 'dart:io';
import '../utils/logger.dart';
import 'package:path_provider/path_provider.dart';
import '../models/local_song.dart';

class LocalMusicService {
  static const _audioExtensions = ['.mp3', '.flac', '.wav', '.aac', '.ogg', '.wma', '.m4a'];

  Future<List<LocalSong>> scanMusic() async {
    final songs = <LocalSong>[];
    final dirs = await _getSearchDirs();
    for (final dir in dirs) {
      await _scanDir(dir, songs);
    }
    return songs;
  }

  Future<List<Directory>> _getSearchDirs() async {
    final dirs = <Directory>[];
    // External storage
    if (Platform.isAndroid) {
      dirs.add(Directory('/storage/emulated/0/Music'));
      dirs.add(Directory('/storage/emulated/0/Download'));
      dirs.add(Directory('/storage/emulated/0/music'));
      dirs.add(Directory('/storage/emulated/0/Music'));
    }
    // App documents
    try {
      final appDir = await getApplicationDocumentsDirectory();
      dirs.add(Directory('${appDir.path}/music'));
    } catch (e, s) { Log.e('local_music_service', 'error', e, s); }
    return dirs;
  }

  Future<void> _scanDir(Directory dir, List<LocalSong> results) async {
    if (!await dir.exists()) return;
    try {
      await for (final entry in dir.list(recursive: true, followLinks: false)) {
        if (entry is File && _isAudioFile(entry.path)) {
          final stat = await entry.stat();
          final name = entry.path.split('/').last;

          // Detect codec and estimate quality from file extension
          final ext = entry.path.toLowerCase();
          String? codec;
          int? bitrate;
          if (ext.endsWith('.flac')) {
            codec = 'FLAC';
            bitrate = 900; // typical FLAC ~900kbps
          } else if (ext.endsWith('.wav')) {
            codec = 'WAV';
            bitrate = 1411; // CD quality WAV
          } else if (ext.endsWith('.mp3')) {
            codec = 'MP3';
          } else if (ext.endsWith('.aac') || ext.endsWith('.m4a')) {
            codec = 'AAC';
          } else if (ext.endsWith('.ogg')) {
            codec = 'OGG';
          } else if (ext.endsWith('.wma')) {
            codec = 'WMA';
          }

          results.add(LocalSong(
            title: name.replaceAll(RegExp(r'\.[^.]+$'), ''),
            filePath: entry.path,
            size: stat.size,
            codec: codec,
            bitrate: bitrate,
          ));
        }
      }
    } catch (e, s) { Log.e('local_music_service', 'error', e, s); }
  }

  bool _isAudioFile(String path) {
    final lower = path.toLowerCase();
    return _audioExtensions.any((ext) => lower.endsWith(ext));
  }
}

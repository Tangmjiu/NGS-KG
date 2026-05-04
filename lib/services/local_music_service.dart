import 'dart:io';
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
    } catch (_) {}
    return dirs;
  }

  Future<void> _scanDir(Directory dir, List<LocalSong> results) async {
    if (!await dir.exists()) return;
    try {
      await for (final entry in dir.list(recursive: true, followLinks: false)) {
        if (entry is File && _isAudioFile(entry.path)) {
          final stat = await entry.stat();
          final name = entry.path.split('/').last;
          results.add(LocalSong(
            title: name.replaceAll(RegExp(r'\.[^.]+$'), ''),
            filePath: entry.path,
            size: stat.size,
          ));
        }
      }
    } catch (_) {}
  }

  bool _isAudioFile(String path) {
    final lower = path.toLowerCase();
    return _audioExtensions.any((ext) => lower.endsWith(ext));
  }
}

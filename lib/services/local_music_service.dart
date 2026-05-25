import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';
import '../models/local_song.dart';
import 'metadata_reader.dart';

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
          final name = entry.path.split('/').last;
          final ext = p.extension(entry.path).toLowerCase();

          // Read metadata from audio file tags
          String title = name.replaceAll(RegExp(r'\.[^.]+$'), '');
          String? artist;
          String? album;
          int duration = 0;
          int? bitrate;
          String? codec;
          String? coverCachePath;

          final meta = await MetadataReader.read(entry);
          if (meta != null) {
            if (meta.title != null && meta.title!.isNotEmpty) {
              title = meta.title!;
            }
            if (meta.artist != null && meta.artist!.isNotEmpty) {
              artist = meta.artist!;
            }
            if (meta.album != null && meta.album!.isNotEmpty) {
              album = meta.album!;
            }
            if (meta.durationMs > 0) {
              duration = (meta.durationMs / 1000).round();
            }
            if (meta.bitrate != null && meta.bitrate! > 0) {
              bitrate = meta.bitrate!;
            }
            // Cache album art
            if (meta.albumArt != null && meta.albumArt!.isNotEmpty) {
              coverCachePath = await _cacheAlbumArt(entry.path, meta.albumArt!);
            }
          }

          // Detect codec and estimate quality from file extension
          if (ext == '.flac') {
            codec = 'FLAC';
            bitrate ??= 900;
          } else if (ext == '.wav') {
            codec = 'WAV';
            bitrate ??= 1411;
          } else if (ext == '.mp3') {
            codec = 'MP3';
          } else if (ext == '.aac' || ext == '.m4a') {
            codec = 'AAC';
          } else if (ext == '.ogg') {
            codec = 'OGG';
          } else if (ext == '.wma') {
            codec = 'WMA';
          }

          // Read companion .lrc file
          String? lyrics;
          final lrcPath = p.setExtension(entry.path, '.lrc');
          final lrcFile = File(lrcPath);
          try {
            if (await lrcFile.exists()) {
              lyrics = await lrcFile.readAsString();
            }
          } catch (e, s) {
            Log.e('local_music_service', 'lrc read error for $lrcPath', e, s);
          }

          final stat = await entry.stat();
          results.add(LocalSong(
            title: title,
            artist: artist,
            album: album,
            filePath: entry.path,
            size: stat.size,
            duration: duration,
            codec: codec,
            bitrate: bitrate,
            lyrics: lyrics,
            albumCoverPath: coverCachePath,
          ));
        }
      }
    } catch (e, s) { Log.e('local_music_service', 'error', e, s); }
  }

  bool _isAudioFile(String path) {
    final lower = path.toLowerCase();
    return _audioExtensions.any((ext) => lower.endsWith(ext));
  }

  /// Caches album art JPEG to app's temporary directory and returns the file path.
  Future<String?> _cacheAlbumArt(String audioPath, Uint8List artData) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final baseName = p.basenameWithoutExtension(audioPath);
      final cacheFile = File('${cacheDir.path}/album_art_$baseName.jpg');
      if (!await cacheFile.exists()) {
        await cacheFile.writeAsBytes(artData);
      }
      return cacheFile.path;
    } catch (e, s) {
      Log.e('local_music_service', 'cover cache error', e, s);
      return null;
    }
  }
}

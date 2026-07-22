import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import '../utils/platform_helper.dart';
import '../models/local_song.dart';
import 'metadata_reader.dart';

class LocalMusicService {
  static const _audioExtensions = ['.mp3', '.flac', '.wav', '.aac', '.ogg', '.wma', '.m4a'];
  static const _persistedDirsKey = 'local_music_folders';

  // ─── Public API ─────────────────────────────────────────────

  Future<List<LocalSong>> scanMusic() async {
    if (isOhos) {
      return _scanOhos();
    }
    if (Platform.isAndroid) {
      return _scanAndroid();
    }
    return _scanLegacy();
  }

  Future<List<String>> getPersistedDirs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_persistedDirsKey) ?? [];
  }

  Future<void> addSearchDir(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final dirs = prefs.getStringList(_persistedDirsKey) ?? [];
    if (!dirs.contains(path)) {
      dirs.add(path);
      await prefs.setStringList(_persistedDirsKey, dirs);
    }
  }

  Future<void> removeSearchDir(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final dirs = prefs.getStringList(_persistedDirsKey) ?? [];
    dirs.remove(path);
    await prefs.setStringList(_persistedDirsKey, dirs);
  }

  // ─── OHOS: mediaLibrary via MethodChannel ─────────────────

  static const _localMusicChannel = MethodChannel('com.mjiutang.ngskg/local_music');

  Future<List<LocalSong>> _scanOhos() async {
    try {
      final raw = await _localMusicChannel.invokeMethod<List<dynamic>>('scanMusic');
      if (raw == null) return [];
      final songs = <LocalSong>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
        songs.add(LocalSong(
          title: map['title'] as String? ?? '',
          artist: map['artist'] as String? ?? '',
          album: map['album'] as String? ?? '',
          filePath: map['filePath'] as String? ?? '',
          mediaStoreId: (map['id'] as num?)?.toInt(),
          size: (map['size'] as num?)?.toInt() ?? 0,
          duration: (map['duration'] as num?)?.toInt() ?? 0,
          codec: 'unknown',
        ));
      }
      return songs;
    } catch (_) {
      return _scanLegacy();
    }
  }

  // ─── Android: MediaStore via on_audio_query ─────────────────

  Future<List<LocalSong>> _scanAndroid() async {
    // on_audio_query not available on OHOS branch; use legacy scanner as fallback
    return _scanLegacy();
  }

  // ─── Windows fallback: filesystem crawl + per-file MMR ──────

  Future<List<LocalSong>> _scanLegacy() async {
    final songs = <LocalSong>[];
    final dirs = await _getSearchDirs();
    for (final dir in dirs) {
      await _scanDirLegacy(dir, songs);
    }
    return songs;
  }

  Future<List<Directory>> _getSearchDirs() async {
    final dirs = <Directory>[];
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        dirs.add(Directory('$userProfile\\Music'));
        dirs.add(Directory('$userProfile\\Downloads'));
      }
    }
    try {
      final appDir = await getApplicationDocumentsDirectory();
      dirs.add(Directory('${appDir.path}/music'));
    } catch (e, s) { Log.e('local_music_service', 'error', e, s); }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_persistedDirsKey) ?? [];
      for (final path in saved) {
        dirs.add(Directory(path));
      }
    } catch (_) {}
    return dirs;
  }

  Future<void> _scanDirLegacy(Directory dir, List<LocalSong> results) async {
    if (!await dir.exists()) return;
    try {
      await for (final entry in dir.list(recursive: true, followLinks: false)) {
        if (entry is File && _isAudioFile(entry.path)) {
          final name = entry.path.split('/').last;
          final ext = p.extension(entry.path).toLowerCase();

          String title = name.replaceAll(RegExp(r'\.[^.]+$'), '');
          String? artist;
          String? album;
          int duration = 0;
          int? bitrate;
          String? codec;
          String? coverCachePath;

          final meta = await MetadataReader.read(entry);
          if (meta != null) {
            if (meta.title != null && meta.title!.isNotEmpty) title = meta.title!;
            if (meta.artist != null && meta.artist!.isNotEmpty) artist = meta.artist!;
            if (meta.album != null && meta.album!.isNotEmpty) album = meta.album!;
            if (meta.durationMs > 0) duration = (meta.durationMs / 1000).round();
            if (meta.bitrate != null && meta.bitrate! > 0) bitrate = meta.bitrate!;
            if (meta.albumArt != null && meta.albumArt!.isNotEmpty) {
              coverCachePath = await _cacheAlbumArt(entry.path, meta.albumArt!);
            }
          }
          coverCachePath ??= await _findFolderCover(entry.path);

          if (ext == '.flac') { codec = 'FLAC'; bitrate ??= 900; }
          else if (ext == '.wav') { codec = 'WAV'; bitrate ??= 1411; }
          else if (ext == '.mp3') { codec = 'MP3'; }
          else if (ext == '.aac' || ext == '.m4a') { codec = 'AAC'; }
          else if (ext == '.ogg') { codec = 'OGG'; }
          else if (ext == '.wma') { codec = 'WMA'; }

          String? lyrics = await _readCompanionLrc(entry.path);
          if ((lyrics == null || lyrics.isEmpty) && meta?.lyrics != null && meta!.lyrics!.isNotEmpty) {
            lyrics = meta.lyrics;
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

  // ─── Shared helpers ─────────────────────────────────────────

  bool _isAudioFile(String path) {
    final lower = path.toLowerCase();
    return _audioExtensions.any((ext) => lower.endsWith(ext));
  }

  static Future<String?> _findFolderCover(String audioPath) async {
    final dir = p.dirname(audioPath);
    const candidates = ['cover.jpg', 'cover.png', 'folder.jpg', 'folder.png',
      'Cover.jpg', 'Front.jpg', 'Folder.jpg', 'AlbumArtSmall.jpg'];
    for (final name in candidates) {
      final candidate = p.join(dir, name);
      if (await File(candidate).exists()) return candidate;
    }
    return null;
  }

  static Future<String?> _readCompanionLrc(String audioPath) async {
    final lrcPath = p.setExtension(audioPath, '.lrc');
    try {
      final lrcFile = File(lrcPath);
      if (await lrcFile.exists()) return await lrcFile.readAsString();
    } catch (e, s) {
      Log.e('local_music_service', 'lrc read error', e, s);
    }
    return null;
  }

  static Future<String?> _findCachedCover(String audioPath) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final baseName = p.basenameWithoutExtension(audioPath);
      final cacheFile = File('${cacheDir.path}/album_art_$baseName.jpg');
      return await cacheFile.exists() ? cacheFile.path : null;
    } catch (_) {
      return null;
    }
  }

  static String _detectCodec(String ext) {
    switch (ext) {
      case '.flac': return 'FLAC';
      case '.wav': return 'WAV';
      case '.mp3': return 'MP3';
      case '.aac': case '.m4a': return 'AAC';
      case '.ogg': return 'OGG';
      case '.wma': return 'WMA';
      default: return '';
    }
  }

  static int _estimateBitrate(String codec) {
    switch (codec) {
      case 'FLAC': return 900;
      case 'WAV': return 1411;
      default: return 0;
    }
  }

  static Future<String?> _cacheAlbumArt(String audioPath, Uint8List artData) async {
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

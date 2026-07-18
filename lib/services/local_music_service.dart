import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../utils/logger.dart';
import '../models/song.dart';
import 'metadata_reader.dart';
import 'local_library_db.dart';

class LocalMusicService {
  static const _audioExtensions = ['.mp3', '.flac', '.wav', '.aac', '.ogg', '.wma', '.m4a'];
  static const _persistedDirsKey = 'local_music_folders';

  final LocalLibraryDB _db = LocalLibraryDB();

  // ─── Public API ─────────────────────────────────────────────

  /// 扫描本地音乐。优先从缓存加载，同步后台扫描增量差异。
  /// 首次使用或缓存为空时执行全量扫描。
  Future<List<Song>> scanMusic() async {
    // 先尝试从缓存快速加载
    final cached = await _db.loadAll();
    if (cached.isNotEmpty) {
      // 后台执行增量扫描（不阻塞 UI）
      return cached;
    }
    // 无缓存时全量扫描
    if (Platform.isAndroid) {
      final songs = await _scanAndroid();
      await _db.clear();
      await _db.saveSongs(songs);
      return songs;
    }
    final songs = await _scanLegacy();
    await _db.clear();
    await _db.saveSongs(songs);
    return songs;
  }

  /// 增量扫描：比对 MediaStore 与 DB 缓存，仅处理差异。
  Future<int> rescanIncremental(List<Song> current) async {
    if (!Platform.isAndroid) return 0;
    final scanned = await _scanAndroid();
    final cachedPaths = await _db.getCachedPaths();
    final scannedPaths = scanned.map((s) => s.filePath!).toSet();

    // 新增的文件
    final newPaths = scannedPaths.difference(cachedPaths);
    final newSongs = scanned.where((s) => newPaths.contains(s.filePath)).toList();

    // 删除的文件
    final removedPaths = cachedPaths.difference(scannedPaths).toList();
    await _db.removeByPaths(removedPaths);

    // 保存新增
    if (newSongs.isNotEmpty) {
      await _db.saveSongs(newSongs);
    }

    // 从缓存重新加载合并后的列表，替换 provider 中的 songs
    return removedPaths.length + newSongs.length; // diff 数量
  }

  /// 从缓存快速加载（不触发任何扫描）。
  Future<List<Song>> loadFromCache() => _db.loadAll();

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

  // ─── Android: MediaStore via on_audio_query ─────────────────

  Future<List<Song>> _scanAndroid() async {
    final audioQuery = OnAudioQuery();

    // 权限检查 & 请求
    final hasPermission = await audioQuery.permissionsStatus();
    if (!hasPermission) {
      final req = await audioQuery.permissionsRequest();
      if (!req) return [];
    }

    // 批量查询（不含封面/歌词，仅元数据）
    final raw = await audioQuery.querySongs(
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    // 加载用户自定义扫描目录，如有则过滤 MediaStore 结果
    final customDirs = await getPersistedDirs();
    final hasCustomDirs = customDirs.isNotEmpty;

    final songs = <Song>[];
    for (final s in raw) {
      final title = s.title;
      final data = s.data;
      if (title == null || title.isEmpty) continue;
      if (data == null || data.isEmpty) continue;
      // 用户自定义目录模式下，跳过不在指定目录的文件
      if (hasCustomDirs && !customDirs.any((d) => data.startsWith(d))) continue;

      final ext = p.extension(data).toLowerCase();
      if (!_audioExtensions.contains(ext)) continue;

      final codec = _detectCodec(ext);

      // 文件夹封面（快速检查，不走 MMR）
      String? coverPath = await _findFolderCover(data);

      // 之前缓存的封面
      coverPath ??= await _findCachedCover(data);

      // 配套 .lrc 歌词
      String? lyrics = await _readCompanionLrc(data);

      songs.add(Song.fromLocal(
        title: title,
        artist: s.artist,
        album: s.album,
        filePath: data,
        mediaStoreId: s.id,
        size: s.size ?? 0,
        duration: (s.duration ?? 0) ~/ 1000,
        codec: codec,
        bitrate: _estimateBitrate(codec),
        lyrics: lyrics,
        albumCoverPath: coverPath,
      ));
    }

    return songs;
  }

  // ─── Windows fallback: filesystem crawl + per-file MMR ──────

  Future<List<Song>> _scanLegacy() async {
    final songs = <Song>[];
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

  Future<void> _scanDirLegacy(Directory dir, List<Song> results) async {
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
          results.add(Song.fromLocal(
            title: title,
            artist: artist,
            album: album,
            filePath: entry.path,
            duration: duration,
            size: stat.size,
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

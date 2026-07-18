import 'dart:convert';
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
  /// 加密/DRM 保护格式：不可播放，扫描时跳过。
  static const _encryptedExtensions = ['.kgm', '.kgg', '.vpr', '.ncm', '.mgg', '.mflac', '.qmc0', '.qmc3', '.qmcflac', '.tkm', '.bkc'];
  /// 文件名包含这些后缀视为加密（如 song.kgm.flac、song.qmcflac.mp3）。
  static const _encryptedNamePatterns = ['kgm.', 'kgg.', 'qmc', 'vpr.', 'ncm.', 'mgg.', 'mflac.', 'tkm.', 'bkc.'];
  static const _persistedDirsKey = 'local_music_folders';

  final LocalLibraryDB _db = LocalLibraryDB();

  // ─── Public API ─────────────────────────────────────────────

  /// 扫描本地音乐。优先从缓存加载，同步后台扫描增量差异。
  /// 首次使用或缓存为空时执行全量扫描。
  Future<List<Song>> scanMusic() async {
    // 先尝试从缓存快速加载
    final cached = await _db.loadAll();
    if (cached.isNotEmpty) {
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

  /// 检测文件是否加密/DRM 保护。
  bool _isEncrypted(String path) {
    final lower = path.toLowerCase();
    for (final ext in _encryptedExtensions) {
      if (lower.endsWith(ext)) return true;
    }
    for (final pattern in _encryptedNamePatterns) {
      if (lower.contains(pattern)) return true;
    }
    return false;
  }

  /// 通过 on_audio_query 查询 MediaStore 专辑封面并缓存。
  Future<String?> _queryArtworkCover(OnAudioQuery audioQuery, int? mediaStoreId) async {
    if (mediaStoreId == null) return null;
    try {
      final artBytes = await audioQuery.queryArtwork(
        mediaStoreId,
        ArtworkType.AUDIO,
        quality: 60,
        size: 360,
      );
      if (artBytes == null || artBytes.isEmpty) return null;
      final cacheDir = await getTemporaryDirectory();
      final cacheFile = File('${cacheDir.path}/album_art_ms_$mediaStoreId.jpg');
      if (!await cacheFile.exists()) {
        await cacheFile.writeAsBytes(artBytes);
      }
      return cacheFile.path;
    } catch (_) {
      return null;
    }
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

      // 跳过加密/DRM 文件（.kgm、.kgm.flac、.ncm 等）
      if (_isEncrypted(data)) continue;

      final codec = _detectCodec(ext);

      // 文件夹封面（快速检查，不走 MMR）
      String? coverPath = await _findFolderCover(data);

      // 之前缓存的封面
      coverPath ??= await _findCachedCover(data);

      // MediaStore 专辑封面（Android 快速 API，无文件 I/O）
      if (coverPath == null && s.id != null) {
        coverPath = await _queryArtworkCover(audioQuery, s.id);
      }

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
          if (_isEncrypted(entry.path)) continue; // 跳过加密文件
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
      if (await lrcFile.exists()) {
        final bytes = await lrcFile.readAsBytes();
        return _decodeText(bytes);
      }
    } catch (e, s) {
      Log.e('local_music_service', 'lrc read error', e, s);
    }
    return null;
  }

  /// 解码字节为字符串：优先 UTF-8，检测 GBK 特征后回退。
  static String _decodeText(Uint8List bytes) {
    // UTF-8 BOM 检测
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return utf8.decode(bytes, allowMalformed: true);
    }
    // 尝试 UTF-8
    try {
      final s = utf8.decode(bytes, allowMalformed: true);
      // 如果包含大量替换字符，可能是 GBK
      final replacementCount = '\uFFFD'.allMatches(s).length;
      if (replacementCount > 0 && replacementCount > s.length * 0.05) {
        return _decodeGbk(bytes);
      }
      return s;
    } catch (_) {
      return _decodeGbk(bytes);
    }
  }

  /// 简易 GBK 解码器（GB2312 兼容）。
  /// 单字节 < 0x80 → ASCII；双字节 → GBK 编码到 Unicode。
  static String _decodeGbk(Uint8List bytes) {
    final buf = StringBuffer();
    int i = 0;
    while (i < bytes.length) {
      final b1 = bytes[i];
      if (b1 < 0x80) {
        buf.writeCharCode(b1);
        i++;
      } else if (i + 1 < bytes.length) {
        final b2 = bytes[i + 1];
        final code = (b1 << 8) | b2;
        buf.writeCharCode(_gbkToUnicode(code));
        i += 2;
      } else {
        i++;
      }
    }
    return buf.toString();
  }

  /// GBK 码点 → Unicode 码点映射（覆盖 GB2312 常用区）。
  static int _gbkToUnicode(int gbk) {
    // GBK/GB2312 → Unicode 偏移映射
    // 高字节 0xA1-0xFE, 低字节 0xA1-0xFE
    // 使用简化映射：直接计算 Unicode 码点
    final hi = (gbk >> 8) & 0xFF;
    final lo = gbk & 0xFF;
    if (hi >= 0xA1 && hi <= 0xA9 && lo >= 0xA1 && lo <= 0xFE) {
      // GB2312 符号区 → 全角字符
      return 0xFF00 + (hi - 0xA0) * 0x5E + (lo - 0xA1);
    }
    if (hi >= 0xB0 && hi <= 0xF7 && lo >= 0xA1 && lo <= 0xFE) {
      // GB2312 汉字区 → 计算 Unicode
      final offset = (hi - 0xB0) * 94 + (lo - 0xA1);
      // 线性映射到 Unicode CJK Unified Ideographs 区
      // 起始点 U+4E00 对应 GB 0xB0A1
      if (hi >= 0xB0 && hi < 0xD8) {
        // 常用汉字区：0xB0A1 → U+4E00
        return 0x4E00 + offset;
      }
      // 其余区域使用近似映射
      return 0x4E00 + offset;
    }
    // 无法映射，返回替换字符
    return 0xFFFD;
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

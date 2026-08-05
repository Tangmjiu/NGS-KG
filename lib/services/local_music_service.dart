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

/// 扫描进度快照，由 [LocalMusicService.scanMusic] 通过回调上报。
class ScanProgress {
  /// 已处理的文件数。
  final int scanned;

  /// 待处理文件总数（0 表示未知，如收集阶段）。
  final int total;

  /// 已发现的有效音频文件数。
  final int found;

  /// 当前正在处理的文件路径。
  final String? currentPath;

  const ScanProgress({
    required this.scanned,
    required this.total,
    required this.found,
    this.currentPath,
  });

  /// 0.0 ~ 1.0 的进度（total 未知时为 -1）。
  double get ratio => total <= 0 ? -1 : (scanned / total).clamp(0.0, 1.0);
}

class LocalMusicService {
  static const _audioExtensions = [
    '.mp3',
    '.flac',
    '.wav',
    '.aac',
    '.ogg',
    '.wma',
    '.m4a'
  ];

  /// 加密/DRM 保护格式：不可播放，扫描时跳过。
  static const _encryptedExtensions = [
    '.kgm',
    '.kgg',
    '.vpr',
    '.ncm',
    '.mgg',
    '.mflac',
    '.qmc0',
    '.qmc3',
    '.qmcflac',
    '.tkm',
    '.bkc'
  ];

  /// 文件名包含这些后缀视为加密（如 song.kgm.flac、song.qmcflac.mp3）。
  static const _encryptedNamePatterns = [
    'kgm.',
    'kgg.',
    'qmc',
    'vpr.',
    'ncm.',
    'mgg.',
    'mflac.',
    'tkm.',
    'bkc.'
  ];
  static const _persistedDirsKey = 'local_music_folders';

  final LocalLibraryDB _db = LocalLibraryDB();

  // ─── Public API ─────────────────────────────────────────────

  /// 扫描本地音乐。有缓存时快速加载，首次或 forced 时全量扫描。
  ///
  /// [onProgress] 在扫描过程中上报进度快照；[isCancelled] 返回 true 时
  /// 尽快中止扫描（已完成的批次结果仍会返回）。
  Future<List<Song>> scanMusic({
    bool forceFull = false,
    void Function(ScanProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (!forceFull) {
      final cached = await _db.loadAll();
      if (cached.isNotEmpty) return cached;
    }
    // 全量扫描
    if (Platform.isAndroid) {
      final songs =
          await _scanAndroid(onProgress: onProgress, isCancelled: isCancelled);
      // 批量提取无封面歌曲的内嵌封面
      final coverMap = await _batchExtractCovers(songs,
          onProgress: onProgress, isCancelled: isCancelled);
      if (coverMap.isNotEmpty) {
        for (var i = 0; i < songs.length; i++) {
          final s = songs[i];
          if (s.filePath != null && coverMap.containsKey(s.filePath)) {
            songs[i] = Song(
              id: s.id,
              name: s.name,
              artists: s.artists,
              albumName: s.albumName,
              albumCoverUrl: Uri.file(coverMap[s.filePath]!).toString(),
              filePath: s.filePath,
              duration: s.duration,
              mediaStoreId: s.mediaStoreId,
              size: s.size,
              bitrate: s.bitrate,
              codec: s.codec,
              lyrics: s.lyrics,
              qualities: s.qualities,
            );
          }
        }
      }
      await _db.clear();
      await _db.saveSongs(songs);
      return songs;
    }
    final songs =
        await _scanDesktop(onProgress: onProgress, isCancelled: isCancelled);
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
  Future<String?> _queryArtworkCover(
      OnAudioQuery audioQuery, int? mediaStoreId) async {
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

  /// 批量提取内嵌封面（并发 4 路），返回 Map<filePath, coverCachePath>。
  Future<Map<String, String>> _batchExtractCovers(
    List<Song> songs, {
    void Function(ScanProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    const concurrency = 4;
    final result = <String, String>{};
    final noCover = songs
        .where((s) => s.albumCoverUrl == null || s.albumCoverUrl!.isEmpty)
        .toList();
    if (noCover.isEmpty) return result;

    var done = 0;
    for (var i = 0; i < noCover.length; i += concurrency) {
      if (isCancelled?.call() ?? false) break;
      final batch = noCover.skip(i).take(concurrency);
      final results = await Future.wait(batch.map((s) async {
        final fp = s.filePath;
        if (fp == null) return null;
        try {
          final file = File(fp);
          if (!await file.exists()) return null;
          final artPath = await _extractEmbeddedCover(file);
          if (artPath != null) {
            await _cacheCoverForPath(fp, artPath);
            return MapEntry(fp, artPath);
          }
        } catch (_) {}
        return null;
      }));
      done += batch.length;
      onProgress?.call(ScanProgress(
        scanned: done,
        total: noCover.length,
        found: result.length,
        currentPath: batch.first.filePath,
      ));
      for (final r in results) {
        if (r != null) result[r.key] = r.value;
      }
    }
    return result;
  }

  Future<void> _cacheCoverForPath(String audioPath, String artPath) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final baseName = p.basenameWithoutExtension(audioPath);
      final cacheFile = File('${cacheDir.path}/album_art_$baseName.jpg');
      if (!await cacheFile.exists()) {
        await File(artPath).copy(cacheFile.path);
      }
    } catch (_) {}
  }

  /// 从音频文件二进制读取内嵌封面。
  static Future<String?> _extractEmbeddedCover(File file) async {
    try {
      final raf = await file.open(mode: FileMode.read);
      try {
        final header = await raf.read(4);
        if (header.length < 3) return null;
        // MP3 ID3v2 APIC
        if (header[0] == 0x49 && header[1] == 0x44 && header[2] == 0x33) {
          await raf.setPosition(6);
          final sb = await raf.read(4);
          final tagEnd =
              10 + ((sb[0] << 21) | (sb[1] << 14) | (sb[2] << 7) | sb[3]);
          var pos = 10;
          while (pos < tagEnd - 10) {
            await raf.setPosition(pos);
            final fh = await raf.read(10);
            if (fh.length < 10) break;
            final fid = String.fromCharCodes(fh.sublist(0, 4));
            final fsz = (fh[4] << 24) | (fh[5] << 16) | (fh[6] << 8) | fh[7];
            if (fid == 'APIC' && fsz > 10) {
              final data = await raf.read(fsz);
              int off = 1;
              while (off < data.length && data[off] != 0) off++;
              off++;
              off++;
              while (off < data.length && data[off] != 0) off++;
              off++;
              if (off < data.length) return _saveCoverBytes(data.sublist(off));
              break;
            }
            pos += 10 + fsz;
          }
          return null;
        }
        // FLAC METADATA_BLOCK_PICTURE
        if (header[0] == 0x66 &&
            header[1] == 0x4C &&
            header[2] == 0x61 &&
            header[3] == 0x43) {
          await raf.setPosition(4);
          var last = false;
          while (!last) {
            final bh = await raf.read(4);
            if (bh.length < 4) break;
            last = (bh[0] & 0x80) != 0;
            final bt = bh[0] & 0x7F;
            final bs = (bh[1] << 16) | (bh[2] << 8) | bh[3];
            if (bt == 6) {
              final data = await raf.read(bs);
              if (data.length < 32) break;
              final ml =
                  (data[4] << 24) | (data[5] << 16) | (data[6] << 8) | data[7];
              var off = 8 + ml;
              if (off + 4 > data.length) break;
              final dl = (data[off] << 24) |
                  (data[off + 1] << 16) |
                  (data[off + 2] << 8) |
                  data[off + 3];
              off += 4 + dl + 16;
              if (off + 4 > data.length) break;
              final pl = (data[off] << 24) |
                  (data[off + 1] << 16) |
                  (data[off + 2] << 8) |
                  data[off + 3];
              off += 4;
              if (off + pl <= data.length)
                return _saveCoverBytes(data.sublist(off, off + pl));
              break;
            }
            await raf.setPosition(raf.positionSync() + bs);
          }
          return null;
        }
      } finally {
        await raf.close();
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> _saveCoverBytes(List<int> bytes) async {
    if (bytes.isEmpty) return null;
    final d = await getTemporaryDirectory();
    final f = File(
        '${d.path}/embedded_${bytes.hashCode}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await f.writeAsBytes(bytes);
    return f.path;
  }

  /// 增量扫描：比对 MediaStore 与 DB 缓存，仅处理差异。
  Future<int> rescanIncremental(List<Song> current) async {
    if (!Platform.isAndroid) return 0;
    final scanned = await _scanAndroid();
    final cachedPaths = await _db.getCachedPaths();
    final scannedPaths = scanned.map((s) => s.filePath!).toSet();

    // 新增的文件
    final newPaths = scannedPaths.difference(cachedPaths);
    final newSongs =
        scanned.where((s) => newPaths.contains(s.filePath)).toList();

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

  Future<List<Song>> _scanAndroid({
    void Function(ScanProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
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
      if (isCancelled?.call() ?? false) break;
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
      onProgress?.call(ScanProgress(
        scanned: songs.length,
        total: raw.length,
        found: songs.length,
        currentPath: data,
      ));
    }

    return songs;
  }

  // ─── Windows/Linux/macOS: filesystem crawl + pure-Dart MMR ──

  Future<List<Song>> _scanDesktop({
    void Function(ScanProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final dirs = await _getSearchDirs();

    // 1. 收集阶段：递归遍历目录，收集音频文件路径（快速，无 I/O 解析）
    final files = <String>[];
    var found = 0;
    for (final dir in dirs) {
      if (isCancelled?.call() ?? false) break;
      await _collectAudioFiles(dir, files, onFound: () {
        found++;
        onProgress?.call(ScanProgress(
          scanned: files.length,
          total: 0,
          found: found,
          currentPath: dir.path,
        ));
      });
    }

    // 2. 解析阶段：并发 4 路读取元数据（标签/封面/时长/码率）
    const concurrency = 4;
    final songs = <Song>[];
    var scanned = 0;
    for (var i = 0; i < files.length; i += concurrency) {
      if (isCancelled?.call() ?? false) break;
      final batch = files.skip(i).take(concurrency).toList();
      final results = await Future.wait(batch.map((f) async {
        final s = await _buildSongFromFile(f);
        return s;
      }));
      scanned += batch.length;
      for (final r in results) {
        if (r != null) songs.add(r);
      }
      onProgress?.call(ScanProgress(
        scanned: scanned,
        total: files.length,
        found: songs.length,
        currentPath: batch.last,
      ));
    }

    return songs;
  }

  /// 递归收集目录下的所有音频文件（不解析元数据，速度优先）。
  Future<void> _collectAudioFiles(
    Directory dir,
    List<String> out, {
    void Function()? onFound,
  }) async {
    if (!await dir.exists()) return;
    try {
      await for (final entry in dir.list(recursive: true, followLinks: false)) {
        if (entry is File && _isAudioFile(entry.path)) {
          if (_isEncrypted(entry.path)) continue; // 跳过加密文件
          out.add(entry.path);
          onFound?.call();
        }
      }
    } catch (e, s) {
      Log.e('local_music_service', 'collect error', e, s);
    }
  }

  /// 读取单个音频文件的完整元数据并构建 Song。
  Future<Song?> _buildSongFromFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final name = path.split(RegExp(r'[\\/]')).last;
      final ext = p.extension(path).toLowerCase();

      String title = name.replaceAll(RegExp(r'\.[^.]+$'), '');
      String? artist;
      String? album;
      int duration = 0;
      int? bitrate;
      String? codec = _detectCodec(ext);
      String? lyrics;
      String? coverCachePath;

      final meta = await MetadataReader.read(file);
      if (meta != null) {
        if (meta.title != null && meta.title!.isNotEmpty) title = meta.title!;
        if (meta.artist != null && meta.artist!.isNotEmpty)
          artist = meta.artist!;
        if (meta.album != null && meta.album!.isNotEmpty) album = meta.album!;
        if (meta.durationMs > 0) duration = (meta.durationMs / 1000).round();
        if (meta.bitrate != null && meta.bitrate! > 0) bitrate = meta.bitrate!;
        if (meta.albumArt != null && meta.albumArt!.isNotEmpty) {
          coverCachePath = await _cacheAlbumArt(path, meta.albumArt!);
        }
        if (meta.lyrics != null && meta.lyrics!.isNotEmpty) {
          lyrics = meta.lyrics;
        }
      }
      coverCachePath ??= await _findFolderCover(path);

      // 无内嵌歌词时读取配套 .lrc
      if (lyrics == null || lyrics.isEmpty) {
        lyrics = await _readCompanionLrc(path);
      }

      if (ext == '.wav' && bitrate == null) bitrate = 1411;
      if (ext == '.flac' && bitrate == null) bitrate = 900;

      final stat = await file.stat();
      return Song.fromLocal(
        title: title,
        artist: artist,
        album: album,
        filePath: path,
        duration: duration,
        size: stat.size,
        codec: codec,
        bitrate: bitrate,
        lyrics: lyrics,
        albumCoverPath: coverCachePath,
      );
    } catch (e, s) {
      Log.e('local_music_service', 'metadata error: $path', e, s);
      return null;
    }
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
    } catch (e, s) {
      Log.e('local_music_service', 'error', e, s);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_persistedDirsKey) ?? [];
      for (final path in saved) {
        dirs.add(Directory(path));
      }
    } catch (_) {}
    return dirs;
  }

  // ─── Shared helpers ─────────────────────────────────────────

  bool _isAudioFile(String path) {
    final lower = path.toLowerCase();
    return _audioExtensions.any((ext) => lower.endsWith(ext));
  }

  static Future<String?> _findFolderCover(String audioPath) async {
    final dir = p.dirname(audioPath);
    const candidates = [
      'cover.jpg',
      'cover.png',
      'folder.jpg',
      'folder.png',
      'Cover.jpg',
      'Front.jpg',
      'Folder.jpg',
      'AlbumArtSmall.jpg'
    ];
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
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
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
      case '.flac':
        return 'FLAC';
      case '.wav':
        return 'WAV';
      case '.mp3':
        return 'MP3';
      case '.aac':
      case '.m4a':
        return 'AAC';
      case '.ogg':
        return 'OGG';
      case '.wma':
        return 'WMA';
      default:
        return '';
    }
  }

  static int _estimateBitrate(String codec) {
    switch (codec) {
      case 'FLAC':
        return 900;
      case 'WAV':
        return 1411;
      default:
        return 0;
    }
  }

  static Future<String?> _cacheAlbumArt(
      String audioPath, Uint8List artData) async {
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

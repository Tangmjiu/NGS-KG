// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ym_lyric/model/krc_language_model.dart';
import 'package:ym_lyric/utils/krc_lyric_util.dart';

import '../models/song.dart';
import '../providers/local_music_provider.dart';
import '../constants/quality.dart';
import '../utils/logger.dart';
import '../utils/navigation.dart' as app;
import 'music_service.dart';

/// 下载/缓存任务状态
enum DownloadStatus { queued, downloading, done, failed, cancelled }

/// 单个下载或缓存任务（对外暴露给 UI）
class DownloadTask {
  /// 唯一键：`{hash}_{quality}_{dl|cache}`（入队时请求音质）
  final String key;

  final Song song;

  /// 下载音质（开始前 privilege 预查后更新为实际可用音质）
  String quality;

  /// 实际请求 URL 时使用的 hash（来自 /privilege/lite 的音质变体 hash）。
  /// 为空时回退使用 [Song.hash]（原始 hash）。
  final String? variantHash;

  /// true = 播放缓存（cache 目录，无元数据）；false = 正式下载（music 目录）
  final bool isCache;

  DownloadStatus status;
  double progress;
  String? error;
  String? filePath;
  int? totalBytes;

  DownloadTask({
    required this.key,
    required this.song,
    required this.quality,
    required this.isCache,
    this.variantHash,
    this.status = DownloadStatus.queued,
    this.progress = 0,
    this.error,
    this.filePath,
    this.totalBytes,
  });
}

/// 歌曲下载 + 播放缓存服务（单例）
///
/// - 正式下载：下载到 `{appDocDir}/music/`，保存封面图和 LRC/KRC 歌词。
///   移动端跳过 ID3v2/FLAC 元数据写入（phonic 仅支持桌面端）。
/// - 播放缓存（先播后缓）：下载到 `{appDocDir}/cache/audio/`，不写元数据，
///   按容量上限清理，下次播放命中时零流量。
class DownloadService extends ChangeNotifier {
  DownloadService._();

  static final DownloadService instance = DownloadService._();

  static const _dbName = 'downloads.db';
  static const _prefCacheEnabled = 'download_cache_enabled';
  static const _prefCacheOnlyWifi = 'download_cache_only_wifi';

  /// 缓存目录容量上限（2GB）
  static const cacheLimitBytes = 2 * 1024 * 1024 * 1024;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(minutes: 10),
  ));

  Database? _db;
  bool _initialized = false;
  bool _processing = false;
  final List<DownloadTask> _queue = [];
  final Map<String, String> _doneDownloads = {}; // hash -> filePath
  final Map<String, String> _cachedFiles = {}; // hash_quality -> filePath
  MusicService? _musicInstance;

  bool _cacheEnabled = true;
  bool _cacheOnlyWifi = false;

  // ─── Getters ───

  bool get cacheEnabled => _cacheEnabled;
  bool get cacheOnlyWifi => _cacheOnlyWifi;

  List<DownloadTask> get tasks => List.unmodifiable(_queue);

  List<DownloadTask> get activeTasks =>
      List.unmodifiable(_queue.where((t) => t.status != DownloadStatus.done));

  List<DownloadTask> get downloads => List.unmodifiable(
      _queue.where((t) => !t.isCache && t.status == DownloadStatus.done));

  List<DownloadTask> get cachedTasks => List.unmodifiable(
      _queue.where((t) => t.isCache && t.status == DownloadStatus.done));

  // ─── 初始化 ───

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cacheEnabled = prefs.getBool(_prefCacheEnabled) ?? true;
      _cacheOnlyWifi = prefs.getBool(_prefCacheOnlyWifi) ?? false;
    } catch (_) {}

    try {
      final dir = await getApplicationDocumentsDirectory();
      _db = await openDatabase(
        p.join(dir.path, _dbName),
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE downloads (
              key TEXT PRIMARY KEY,
              hash TEXT NOT NULL,
              quality TEXT NOT NULL,
              song_id INTEGER NOT NULL,
              name TEXT NOT NULL,
              artist TEXT,
              album TEXT,
              file_path TEXT NOT NULL,
              size INTEGER NOT NULL,
              kind TEXT NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          await db
              .execute('CREATE INDEX idx_downloads_kind ON downloads(kind)');
          await db
              .execute('CREATE INDEX idx_downloads_hash ON downloads(hash)');
        },
      );
      await _loadRecords();
    } catch (e, s) {
      Log.e('download_service', 'init db error', e, s);
    }
  }

  Future<void> _loadRecords() async {
    final rows = await _db!.query('downloads', orderBy: 'created_at DESC');
    for (final row in rows) {
      final path = row['file_path'] as String;
      if (!await File(path).exists()) {
        await _db!
            .delete('downloads', where: 'key = ?', whereArgs: [row['key']]);
        continue;
      }
      final kind = row['kind'] as String;
      final hash = row['hash'] as String;
      if (kind == 'cache') {
        _cachedFiles['${hash}_${row['quality']}'] = path;
      } else {
        _doneDownloads[hash] = path;
      }
    }
  }

  MusicService _music() => _musicInstance ??= MusicService();

  // ─── 设置 ───

  Future<void> setCacheEnabled(bool value) async {
    _cacheEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefCacheEnabled, value);
    } catch (_) {}
  }

  Future<void> setCacheOnlyWifi(bool value) async {
    _cacheOnlyWifi = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefCacheOnlyWifi, value);
    } catch (_) {}
  }

  // ─── 查询 ───

  bool isDownloaded(Song song) {
    final hash = song.hash;
    if (hash == null || hash.isEmpty) return false;
    return _doneDownloads.containsKey(hash);
  }

  bool isCached(Song song, String quality) {
    final hash = song.hash;
    if (hash == null || hash.isEmpty) return false;
    return _cachedFiles.containsKey('${hash}_$quality');
  }

  /// 播放用本地路径：优先已下载（任意音质），其次同音质缓存
  Future<String?> getLocalPlayPath(Song song, String quality) async {
    final hash = song.hash;
    if (hash == null || hash.isEmpty) return null;
    final downloaded = _doneDownloads[hash];
    if (downloaded != null && await File(downloaded).exists()) {
      return downloaded;
    }
    final cached = _cachedFiles['${hash}_$quality'];
    if (cached != null && await File(cached).exists()) {
      return cached;
    }
    return null;
  }

  bool isQueuedOrDownloading(String key) {
    for (final t in _queue) {
      if (t.key == key &&
          (t.status == DownloadStatus.queued ||
              t.status == DownloadStatus.downloading)) {
        return true;
      }
    }
    return false;
  }

  // ─── 下载入口 ───

  /// 正式下载歌曲。已下载/排队中则忽略。
  Future<void> download(Song song, {String? quality}) async {
    final hash = song.hash;
    if (hash == null || hash.isEmpty) {
      Log.w('download_service', 'download skipped: no hash for ${song.name}');
      return;
    }
    if (song.isLocal) {
      Log.w('download_service', 'download skipped: local song ${song.name}');
      return;
    }
    final q = quality ?? 'high';
    if (isDownloaded(song)) return;
    final key = '${hash}_${q}_dl';
    if (isQueuedOrDownloading(key)) return;
    _queue.add(DownloadTask(
      key: key,
      song: song,
      quality: q,
      isCache: false,
    ));
    notifyListeners();
    _pump();
  }

  /// 播放后触发的"先播后缓"
  Future<void> maybeCacheSong(Song song, String quality,
      {String? variantHash}) async {
    if (!_cacheEnabled) return;
    final hash = song.hash;
    if (hash == null || hash.isEmpty) return;
    if (song.isLocal) return;
    if (isDownloaded(song)) return;
    if (isCached(song, quality)) return;
    final key = '${hash}_${quality}_cache';
    if (isQueuedOrDownloading(key)) return;
    if (_cacheOnlyWifi && !await _isWifi()) return;
    _queue.add(DownloadTask(
      key: key,
      song: song,
      quality: quality,
      isCache: true,
      variantHash: variantHash,
    ));
    notifyListeners();
    _pump();
  }

  void cancel(String key) {
    for (final t in _queue) {
      if (t.key == key) {
        if (t.status == DownloadStatus.queued ||
            t.status == DownloadStatus.downloading) {
          t.status = DownloadStatus.cancelled;
          notifyListeners();
        }
        return;
      }
    }
  }

  // ─── 队列处理（串行） ───

  Future<void> _pump() async {
    if (_processing) return;
    _processing = true;
    try {
      DownloadTask? next;
      while (true) {
        next = null;
        for (final t in _queue) {
          if (t.status == DownloadStatus.queued) {
            next = t;
            break;
          }
        }
        if (next == null) break;
        await _runTask(next);
      }
    } finally {
      _processing = false;
    }
  }

  Future<void> _runTask(DownloadTask task) async {
    task.status = DownloadStatus.downloading;
    task.progress = 0;
    notifyListeners();
    try {
      String hash = task.song.hash ?? '';
      if (task.isCache &&
          task.variantHash != null &&
          task.variantHash!.isNotEmpty) {
        hash = task.variantHash!;
      } else {
        try {
          final requested = task.quality;
          final res = await _music().getPrivilegeLite(hash);
          final info = PrivilegeInfo.fromJson(res);
          final candidates = info.candidates(task.quality, fallbackHash: hash);
          if (candidates.isNotEmpty) {
            hash =
                candidates.first.hash.isNotEmpty ? candidates.first.hash : hash;
            task.quality = candidates.first.value;
            Log.i('download_service',
                'quality resolved: ${task.quality} (requested $requested)');
          }
        } catch (e) {
          Log.w('download_service',
              'privilege resolve failed, keep requested quality', e);
        }
      }

      final songUrl = await _music()
          .getSongUrl(task.song.id, hash: hash, quality: task.quality);
      if (songUrl.url.isEmpty) {
        throw Exception('未获取到播放地址（音质 ${task.quality}）');
      }
      if (songUrl.isVideo) {
        throw Exception('该音质暂不可用，请尝试其他音质');
      }

      final dir = task.isCache ? await _getCacheDir() : await _getMusicDir();
      await Directory(dir.path).create(recursive: true);

      final ext = _extensionFor(songUrl.type, task.quality);
      final tempFile = File(p.join(dir.path, '.${task.key}.part'));
      final finalName =
          task.isCache ? '${task.key}$ext' : '${_safeBaseName(task)}.$ext';
      final finalFile = File(p.join(dir.path, finalName));

      final resp = await _dio.download(
        songUrl.url,
        tempFile.path,
        onReceiveProgress: (received, total) {
          task.progress = total > 0
              ? received / total
              : (received / 1048576).clamp(0.0, 0.99);
          task.totalBytes = total > 0 ? total : null;
          notifyListeners();
        },
        options: Options(
          followRedirects: true,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14; NGS-KG+) AppleWebKit/537.36',
          },
        ),
      );

      if (task.status == DownloadStatus.cancelled) {
        if (await tempFile.exists()) await tempFile.delete();
        return;
      }
      if (resp.statusCode != 200) {
        throw Exception('下载失败 HTTP ${resp.statusCode}');
      }
      if (!await tempFile.exists() || await tempFile.length() < 1024) {
        throw Exception('下载文件不完整');
      }

      // 正式下载：保存封面 + 歌词到同目录
      if (!task.isCache) {
        await _saveSidecarFiles(tempFile, task);
      }

      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFile.rename(finalFile.path);
      task.progress = 1.0;
      task.filePath = finalFile.path;
      task.status = DownloadStatus.done;

      await _recordDone(task);
      Log.i('download_service',
          '${task.isCache ? 'cache' : 'download'} done: ${finalFile.path}');
    } catch (e, s) {
      Log.w('download_service', 'task ${task.key} failed', e, s);
      if (task.status != DownloadStatus.cancelled) {
        task.status = DownloadStatus.failed;
        task.error = e.toString();
      }
      try {
        final dir = task.isCache ? await _getCacheDir() : await _getMusicDir();
        final tempFile = File(p.join(dir.path, '.${task.key}.part'));
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
    }
    notifyListeners();
    _cleanupQueue();
  }

  void _cleanupQueue() {
    _queue.removeWhere((t) =>
        t.status == DownloadStatus.cancelled ||
        t.status == DownloadStatus.failed);
    if (_queue.length > 300) {
      _queue.removeRange(0, _queue.length - 300);
    }
  }

  // ─── 移动端：保存封面图和歌词为独立文件 ───

  Future<void> _saveSidecarFiles(File tempFile, DownloadTask task) async {
    final song = task.song;
    final dir = p.dirname(tempFile.path);
    final baseName = p.basenameWithoutExtension(tempFile.path);

    // 1. 下载封面图
    try {
      final coverUrl = song.albumCoverUrl?.replaceAll('{size}', '480');
      if (coverUrl != null && coverUrl.isNotEmpty) {
        final resp = await _dio.get<List<int>>(
          coverUrl,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 14; NGS-KG+) AppleWebKit/537.36',
            },
          ),
        );
        final data = resp.data;
        if (data != null && data.isNotEmpty) {
          final coverExt = _detectMime(Uint8List.fromList(data)) == 'image/png'
              ? 'png'
              : 'jpg';
          final coverFile = File(p.join(dir, '$baseName.$coverExt'));
          await coverFile.writeAsBytes(data, flush: true);
        }
      }
    } catch (e) {
      Log.w('download_service', 'cover download failed', e);
    }

    // 2. 下载歌词（KRC → LRC）
    try {
      final searchRes = await _music()
          .searchLyricByHash(song.hash ?? '', keywords: song.name);
      final data = searchRes['data'] as Map<String, dynamic>? ?? searchRes;
      final candidates = data['candidates'] as List<dynamic>? ?? [];
      if (candidates.isNotEmpty) {
        final c = candidates[0] as Map<String, dynamic>;
        final id = int.parse(c['id'].toString());
        final accessKey = c['accesskey'] as String? ?? '';
        final rawKrc = await _music().fetchKrcContent(id, accessKey);
        if (rawKrc.isNotEmpty) {
          // 保存原始 KRC
          final krcFile = File(p.join(dir, '$baseName.krc'));
          await krcFile.writeAsBytes(rawKrc, flush: true);
          // 转换并保存 LRC
          final lrcText = _krcToLrc(rawKrc);
          if (lrcText != null && lrcText.isNotEmpty) {
            final lrcFile = File(p.join(dir, '$baseName.lrc'));
            await lrcFile.writeAsString(lrcText, flush: true);
          }
        } else {
          final rawLrc = await _music().fetchLyricContent(id, accessKey);
          if (rawLrc.isNotEmpty) {
            String lrc;
            try {
              lrc = utf8.decode(base64Decode(rawLrc));
            } catch (_) {
              lrc = rawLrc;
            }
            final lrcFile = File(p.join(dir, '$baseName.lrc'));
            await lrcFile.writeAsString(lrc, flush: true);
          }
        }
      }
    } catch (e, s) {
      Log.w('download_service', 'lyric fetch failed', e, s);
    }
  }

  /// KRC 加密字节 → LRC 文本（原文 + 首语言翻译行）
  String? _krcToLrc(Uint8List krcBytes) {
    try {
      final model = KrcLyricUtil.parseLyrics(krcBytes);
      if (model.krcLyricList.isEmpty) return null;

      final buf = StringBuffer();
      final tag = model.lyricTag;
      if (tag.ti != null && tag.ti!.isNotEmpty) buf.writeln('[ti:${tag.ti}]');
      if (tag.ar != null && tag.ar!.isNotEmpty) buf.writeln('[ar:${tag.ar}]');
      if (tag.al != null && tag.al!.isNotEmpty) buf.writeln('[al:${tag.al}]');
      if (tag.offset != null && tag.offset!.isNotEmpty) {
        buf.writeln('[offset:${tag.offset}]');
      }

      List<String>? transLines;
      try {
        final langJson = tag.language;
        if (langJson != null && langJson.isNotEmpty) {
          final lang = KrcLanguage.fromJson(
              jsonDecode(utf8.decode(base64Decode(langJson))));
          for (final c in lang.content) {
            if (c.language != 0 && c.lyricContent.isNotEmpty) {
              transLines = c.lyricContent.map((words) => words.join()).toList();
              break;
            }
          }
        }
      } catch (e) {
        Log.w('download_service', 'krc translation parse failed', e);
      }

      for (var i = 0; i < model.krcLyricList.length; i++) {
        final line = model.krcLyricList[i];
        final text = line.getWordLine();
        if (text.isEmpty) continue;
        final time = _formatLrcTime(line.startTime);
        buf.writeln('[$time]$text');
        if (transLines != null && i < transLines.length) {
          final tr = transLines[i];
          if (tr.isNotEmpty && tr != text) {
            buf.writeln('[$time]$tr');
          }
        }
      }
      return buf.toString();
    } catch (e, s) {
      Log.w('download_service', 'krc to lrc failed', e, s);
      return null;
    }
  }

  static String _formatLrcTime(int ms) {
    final cs = ms ~/ 10;
    final m = cs ~/ 6000;
    final s = (cs % 6000) ~/ 100;
    final c = cs % 100;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${c.toString().padLeft(2, '0')}';
  }

  static String? _detectMime(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    return null;
  }

  // ─── 文件与记录 ───

  static String _extensionFor(String type, String quality) {
    final t = type.toLowerCase();
    if (t == 'mp3' ||
        t == 'flac' ||
        t == 'wav' ||
        t == 'm4a' ||
        t == 'aac' ||
        t == 'ogg') {
      return t;
    }
    return quality == 'flac' || quality == 'high' ? 'flac' : 'mp3';
  }

  static String _safeBaseName(DownloadTask task) {
    final artist =
        task.song.artists.isNotEmpty ? task.song.artists.first : '未知歌手';
    return '${_sanitize(artist)} - ${_sanitize(task.song.name)}';
  }

  static String _sanitize(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? '未知' : cleaned;
  }

  Future<void> _recordDone(DownloadTask task) async {
    if (_db == null) return;
    final hash = task.song.hash ?? '';
    await _db!.insert(
      'downloads',
      {
        'key': task.key,
        'hash': hash,
        'quality': task.quality,
        'song_id': task.song.id,
        'name': task.song.name,
        'artist': task.song.artists.join(' / '),
        'album': task.song.albumName,
        'file_path': task.filePath!,
        'size': await File(task.filePath!).length(),
        'kind': task.isCache ? 'cache' : 'download',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (task.isCache) {
      _cachedFiles['${hash}_${task.quality}'] = task.filePath!;
      await _enforceCacheLimit();
    } else {
      _doneDownloads[hash] = task.filePath!;
      unawaited(_notifyLocalLibrary(task.filePath!));
    }
    notifyListeners();
  }

  Future<void> _notifyLocalLibrary(String filePath) async {
    try {
      final ctx = app.navKey.currentContext;
      if (ctx == null) return;
      final local = ctx.read<LocalMusicProvider>();
      if (local.scanned) {
        await local.addSongFromPath(filePath);
      }
    } catch (e, s) {
      Log.w('download_service', 'local library notify failed', e, s);
    }
  }

  Future<void> _enforceCacheLimit() async {
    try {
      final dir = await _getCacheDir();
      if (!await dir.exists()) return;
      final files = <(File, int)>[];
      var total = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          final modified = stat.modified.millisecondsSinceEpoch;
          files.add((entity, modified));
          total += stat.size;
        }
      }
      if (total <= cacheLimitBytes) return;
      files.sort((a, b) => a.$2.compareTo(b.$2));
      for (final (file, _) in files) {
        if (total <= cacheLimitBytes) break;
        final size = await file.length();
        await file.delete();
        _cachedFiles.removeWhere((k, v) => v == file.path);
        if (_db != null) {
          await _db!.delete('downloads',
              where: 'file_path = ?', whereArgs: [file.path]);
        }
        total -= size;
        notifyListeners();
      }
    } catch (e, s) {
      Log.w('download_service', 'cache limit enforce failed', e, s);
    }
  }

  Future<void> removeDownload(Song song) async {
    final hash = song.hash;
    if (hash == null || hash.isEmpty) return;
    final path = _doneDownloads.remove(hash);
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) {
          // 同时删除同目录下的 sidecar 文件（封面、歌词）
          final dir = p.dirname(f.path);
          final baseName = p.basenameWithoutExtension(f.path);
          for (final ext in ['jpg', 'png', 'lrc', 'krc']) {
            final sidecar = File(p.join(dir, '$baseName.$ext'));
            if (await sidecar.exists()) await sidecar.delete();
          }
          await f.delete();
        }
      } catch (_) {}
      if (_db != null) {
        await _db!.delete('downloads',
            where: 'hash = ? AND kind = ?', whereArgs: [hash, 'download']);
      }
    }
    notifyListeners();
  }

  Future<int> clearCache() async {
    var removed = 0;
    try {
      final dir = await _getCacheDir();
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File) {
            removed += await entity.length();
            await entity.delete();
          }
        }
      }
      _cachedFiles.clear();
      if (_db != null) {
        await _db!
            .delete('downloads', where: 'kind = ?', whereArgs: ['cache']);
      }
      notifyListeners();
    } catch (e, s) {
      Log.w('download_service', 'clear cache failed', e, s);
    }
    return removed;
  }

  Future<int> cacheTotalBytes() async {
    var total = 0;
    try {
      final dir = await _getCacheDir();
      if (!await dir.exists()) return 0;
      await for (final entity in dir.list()) {
        if (entity is File) total += await entity.length();
      }
    } catch (_) {}
    return total;
  }

  Future<Directory> getCacheDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'cache', 'audio'));
  }

  Future<Directory> getMusicDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'music'));
  }

  Future<Directory> _getCacheDir() => getCacheDir();
  Future<Directory> _getMusicDir() => getMusicDir();

  Future<bool> _isWifi() async {
    try {
      final conn = await Connectivity().checkConnectivity();
      return conn.contains(ConnectivityResult.wifi);
    } catch (_) {
      return true;
    }
  }
}

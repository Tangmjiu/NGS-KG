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
import 'package:phonic/phonic.dart';
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
  /// 注意：任务 key / DB / 缓存索引始终基于 [Song.hash]，保证查询一致。
  final String? variantHash;

  /// true = 播放缓存（cache 目录，无元数据）；false = 正式下载（music 目录，含元数据 + KRC）
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
/// - 正式下载：下载到 `{appDocDir}/music/`，写入 ID3v2 / FLAC Vorbis 元数据
///   （标题/歌手/专辑/封面 + LRC 文本歌词 + 原始 KRC 自定义帧），下载后自动
///   被本地音乐库扫描收录。
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

  /// 任务列表快照（进行中 + 已完成记录）
  List<DownloadTask> get tasks => List.unmodifiable(_queue);

  List<DownloadTask> get activeTasks =>
      List.unmodifiable(_queue.where((t) => t.status != DownloadStatus.done));

  /// 已完成的正式下载任务
  List<DownloadTask> get downloads => List.unmodifiable(
      _queue.where((t) => !t.isCache && t.status == DownloadStatus.done));

  /// 已完成的缓存任务
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

  /// 正式下载歌曲（含元数据 + KRC 内嵌）。已下载/排队中则忽略。
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

  /// 播放后触发的"先播后缓"：非本地歌、未下载、未缓存且开关开启时后台缓存。
  ///
  /// [variantHash] 为播放实际解析到的音质变体 hash（来自 /privilege/lite），
  /// 传入后 [_runTask] 直接用该 hash 请求，避免二次预查降级导致
  /// 任务 key（请求音质）与缓存索引（实际音质）不一致而永远无法命中。
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
      // 1. 解析请求 URL 用的 hash：
      //    - 播放缓存：直接使用播放链路已解析出的变体 hash（避免二次预查降级
      //      导致任务 key 与缓存索引音质不一致、缓存永远 miss）
      //    - 其他（正式下载）：privilege 预查解析实际可用的最高音质及其 hash，
      //      防止 API 对不可用音质静默降级导致"标注 Hi-Res 实为 128kbps"。
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

      // 正式下载：写入元数据 + KRC 歌词
      if (!task.isCache) {
        await _writeMetadata(tempFile, task);
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

  /// 移除已结束（取消/失败）的任务，并限制任务列表长度
  void _cleanupQueue() {
    _queue.removeWhere((t) =>
        t.status == DownloadStatus.cancelled ||
        t.status == DownloadStatus.failed);
    if (_queue.length > 300) {
      _queue.removeRange(0, _queue.length - 300);
    }
  }

  // ─── 元数据写入（phonic） ───

  Future<void> _writeMetadata(File tempFile, DownloadTask task) async {
    final song = task.song;

    // 1. 封面（失败不阻塞下载）
    Uint8List? coverBytes;
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
          coverBytes = Uint8List.fromList(data);
        }
      }
    } catch (e) {
      Log.w('download_service', 'cover download failed', e);
    }

    // 2. 歌词：优先 KRC → 转 LRC 文本；降级 LRC 原文
    Uint8List? krcBytes;
    String? lrcText;
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
          krcBytes = rawKrc;
          lrcText = _krcToLrc(rawKrc);
        }
        if (lrcText == null || lrcText.isEmpty) {
          final rawLrc = await _music().fetchLyricContent(id, accessKey);
          if (rawLrc.isNotEmpty) {
            try {
              lrcText = utf8.decode(base64Decode(rawLrc));
            } catch (_) {
              lrcText = rawLrc;
            }
          }
        }
      }
    } catch (e, s) {
      Log.w('download_service', 'lyric fetch failed', e, s);
    }

    // 3. 写标签（phonic：ID3v2 / FLAC Vorbis）
    try {
      final audioFile = await Phonic.fromFileAsync(tempFile.path);
      try {
        audioFile.setTag(TitleTag(song.name));
        if (song.artists.isNotEmpty) {
          audioFile.setTag(ArtistTag(song.artists.join(' / ')));
        }
        if (song.albumName != null && song.albumName!.isNotEmpty) {
          audioFile.setTag(AlbumTag(song.albumName!));
        }
        if (lrcText != null && lrcText.isNotEmpty) {
          audioFile.setTag(LyricsTag(lrcText));
        }
        if (coverBytes != null && coverBytes.isNotEmpty) {
          audioFile.setTag(ArtworkTag(ArtworkData.immediate(
            mimeType: _detectMime(coverBytes) ?? 'image/jpeg',
            type: ArtworkType.frontCover,
            description: 'Cover',
            data: coverBytes,
          )));
        }
        if (krcBytes != null && krcBytes.isNotEmpty) {
          // 原始 KRC 二进制（base64）存自定义帧，翻译/逐字信息完整保留
          audioFile.setTag(CustomTag('NGSKG_KRC:${base64Encode(krcBytes)}'));
        }
        if (audioFile.isDirty) {
          final bytes = await audioFile.encode();
          await tempFile.writeAsBytes(bytes, flush: true);
        }
      } finally {
        audioFile.dispose();
      }
    } catch (e, s) {
      Log.w('download_service', 'metadata write failed (file kept)', e, s);
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

      // 翻译（language 0 = 中文原文，取第一个非 0 语言作为翻译行）
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

  /// 毫秒 → mm:ss.xx（百分秒）
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
      // 通知本地音乐库即时收录（读取已写入的元数据 + 内嵌歌词）
      unawaited(_notifyLocalLibrary(task.filePath!));
    }
    notifyListeners();
  }

  /// 通过 navKey 通知 LocalMusicProvider 收录下载完成的文件
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
      // 按修改时间升序（最旧优先）清理
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

  /// 删除正式下载（文件 + 记录）
  Future<void> removeDownload(Song song) async {
    final hash = song.hash;
    if (hash == null || hash.isEmpty) return;
    final path = _doneDownloads.remove(hash);
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      if (_db != null) {
        await _db!.delete('downloads',
            where: 'hash = ? AND kind = ?', whereArgs: [hash, 'download']);
      }
    }
    notifyListeners();
  }

  /// 清空缓存目录 + 记录，返回释放的字节数
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
        await _db!.delete('downloads', where: 'kind = ?', whereArgs: ['cache']);
      }
      notifyListeners();
    } catch (e, s) {
      Log.w('download_service', 'clear cache failed', e, s);
    }
    return removed;
  }

  /// 缓存总字节数
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

// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 音频边播边缓存服务 -- 流式播放的同时后台下载到本地, 下次秒开

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// 音频文件缓存管理。
///
/// - 播放在线歌曲时, 流式播放 (just_audio setUrl) 不阻塞
/// - 同时用 Dio 后台下载完整文件到 {appDocDir}/audio_cache/
/// - 下次播放同一首歌时, 如果缓存文件存在且完整, 直接用本地文件秒开
/// - 支持清除缓存和 LRU 容量管理 (默认上限 300MB)
class AudioCacheService {
  AudioCacheService._();
  static final AudioCacheService instance = AudioCacheService._();

  static const int _maxCacheBytes = 300 * 1024 * 1024; // 300MB

  final Dio _dio = Dio();
  Directory? _cacheDir;
  final Map<String, bool> _downloading = {};

  Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/audio_cache');
    if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);
    _cacheDir = cacheDir;
    return cacheDir;
  }

  String _extractExt(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return 'mp3';
    final path = uri.path.toLowerCase();
    if (path.endsWith('.flac')) return 'flac';
    if (path.endsWith('.m4a')) return 'm4a';
    if (path.endsWith('.ogg')) return 'ogg';
    if (path.endsWith('.wav')) return 'wav';
    return 'mp3';
  }

  /// 检查缓存是否存在且完整 (大小 > 0).
  Future<bool> isCached(String hash) async {
    if (hash.isEmpty) return false;
    final dir = await _getCacheDir();
    for (final ext in ['mp3', 'flac', 'm4a', 'ogg', 'wav']) {
      final file = File('${dir.path}/$hash.$ext');
      if (file.existsSync() && file.lengthSync() > 0) return true;
    }
    return false;
  }

  /// 获取缓存文件路径 (如果存在).
  Future<String?> getCachedPath(String hash) async {
    if (hash.isEmpty) return null;
    final dir = await _getCacheDir();
    for (final ext in ['mp3', 'flac', 'm4a', 'ogg', 'wav']) {
      final file = File('${dir.path}/$hash.$ext');
      if (file.existsSync() && file.lengthSync() > 0) return file.path;
    }
    return null;
  }

  /// 后台下载音频文件到缓存 (不阻塞播放).
  Future<void> downloadInBackground(String hash, String url) async {
    if (hash.isEmpty || url.isEmpty) return;
    if (_downloading[hash] == true) return;
    if (await isCached(hash)) return;

    _downloading[hash] = true;
    try {
      final dir = await _getCacheDir();
      final ext = _extractExt(url);
      final tempPath = '${dir.path}/$hash.$ext.tmp';
      final finalPath = '${dir.path}/$hash.$ext';

      await _dio.download(
        url,
        tempPath,
        options: Options(receiveTimeout: const Duration(minutes: 5)),
      );

      final tempFile = File(tempPath);
      if (tempFile.existsSync()) {
        tempFile.renameSync(finalPath);
        _enforceCapacity();
      }
    } catch (_) {
      // 下载失败静默处理
    } finally {
      _downloading.remove(hash);
    }
  }

  /// LRU 容量管理.
  Future<void> _enforceCapacity() async {
    try {
      final dir = await _getCacheDir();
      final files = dir.listSync().whereType<File>().toList();
      int totalSize = files.fold(0, (sum, f) => sum + f.lengthSync());
      if (totalSize <= _maxCacheBytes) return;

      files.sort(
          (a, b) => a.statSync().modified.compareTo(b.statSync().modified));

      for (final file in files) {
        totalSize -= file.lengthSync();
        file.deleteSync();
        if (totalSize <= _maxCacheBytes) break;
      }
    } catch (_) {}
  }

  /// 清除全部音频缓存.
  Future<void> clearCache() async {
    try {
      final dir = await _getCacheDir();
      for (final entity in dir.listSync()) {
        entity.deleteSync();
      }
    } catch (_) {}
  }

  /// 获取当前缓存总大小 (字节).
  Future<int> getCacheSize() async {
    try {
      final dir = await _getCacheDir();
      return dir
          .listSync()
          .whereType<File>()
          .fold<int>(0, (sum, f) => sum + f.lengthSync());
    } catch (_) {
      return 0;
    }
  }

  /// 格式化缓存大小.
  Future<String> getCacheSizeFormatted() async {
    final bytes = await getCacheSize();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

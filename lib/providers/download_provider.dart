// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../services/download_service.dart';

/// 下载与缓存状态管理（UI 层入口）
class DownloadProvider extends ChangeNotifier {
  DownloadProvider() {
    _service.addListener(_onServiceChanged);
    _service.init();
  }

  final DownloadService _service = DownloadService.instance;

  void _onServiceChanged() => notifyListeners();

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  // ─── 透传 ───

  List<DownloadTask> get tasks => _service.tasks;
  List<DownloadTask> get activeTasks => _service.activeTasks;
  List<DownloadTask> get downloads => _service.downloads;
  List<DownloadTask> get cachedTasks => _service.cachedTasks;

  bool get cacheEnabled => _service.cacheEnabled;
  bool get cacheOnlyWifi => _service.cacheOnlyWifi;

  Future<void> setCacheEnabled(bool value) => _service.setCacheEnabled(value);
  Future<void> setCacheOnlyWifi(bool value) => _service.setCacheOnlyWifi(value);

  bool isDownloaded(Song song) => _service.isDownloaded(song);
  bool isCached(Song song, String quality) => _service.isCached(song, quality);

  Future<String?> getLocalPlayPath(Song song, String quality) =>
      _service.getLocalPlayPath(song, quality);

  Future<void> download(Song song, {String? quality}) =>
      _service.download(song, quality: quality);

  Future<void> maybeCacheSong(Song song, String quality) =>
      _service.maybeCacheSong(song, quality);

  void cancel(String key) => _service.cancel(key);

  Future<void> removeDownload(Song song) => _service.removeDownload(song);

  Future<int> clearCache() => _service.clearCache();
  Future<int> cacheTotalBytes() => _service.cacheTotalBytes();
}

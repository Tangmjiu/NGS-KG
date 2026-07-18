import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../services/local_music_service.dart';
import '../services/metadata_reader.dart';
import '../utils/logger.dart';

class LocalMusicProvider extends ChangeNotifier {
  final LocalMusicService _service = LocalMusicService();

  // State
  List<Song> _songs = [];
  List<Song> get songs => _filteredSongs;
  List<Song> _filteredSongs = [];

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  String? _error;
  String? get error => _error;

  String _status = '';
  String get status => _status;

  bool _scanned = false;
  bool get scanned => _scanned;

  // Search / Sort
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String _sortField = 'title';
  String get sortField => _sortField;

  bool _sortAscending = true;
  bool get sortAscending => _sortAscending;

  // Methods
  Future<void> scanMusic({bool forceFull = false}) async {
    if (_isScanning) return;
    _isScanning = true;
    _error = null;
    _status = forceFull ? '正在扫描...' : '正在加载...';
    notifyListeners();
    try {
      final songs = await _service.scanMusic(forceFull: forceFull);
      // Dedup by filePath
      final seen = <String>{};
      _songs = [];
      for (final s in songs) {
        if (seen.add(s.filePath!)) _songs.add(s);
      }
      _scanned = true;
      _applyFilterAndSort();
      _status = _songs.isEmpty ? '未找到本地音乐' : '找到 ${_songs.length} 首';
    } catch (e, s) {
      Log.e('local_music_provider', 'scan error', e, s);
      _error = '扫描失败';
      _status = '扫描失败';
    }
    _isScanning = false;
    notifyListeners();
  }

  /// 强制全量重新扫描（提取内嵌封面）。
  Future<void> refreshLibrary() => scanMusic(forceFull: true);

  /// 按需加载嵌入封面和歌词（必须 await）。
  ///
  /// 当用户点击歌曲时调用，读取完整内嵌封面并缓存到磁盘，
  /// 然后原地更新 _songs 中的条目。
  Future<void> loadDeferredMetadata(Song song) async {
    final meta = await MetadataReader.readDeferred(song);
    if (meta == null) return;

    // 原地更新 _songs 中的条目
    final idx = _songs.indexWhere((s) => s.filePath == song.filePath);
    if (idx == -1) return;

    final coverPath = meta.albumCoverCachePath ??
        await MetadataReader.cachedCoverPath(song.filePath!) ??
        song.albumCoverUrl;

    final old = _songs[idx];
    final updated = Song(
      id: old.id,
      name: old.name,
      artists: (meta.artist != null && meta.artist!.isNotEmpty)
          ? [meta.artist!]
          : old.artists,
      albumName: meta.album ?? old.albumName,
      albumCoverUrl: coverPath != null && coverPath.startsWith('/')
          ? Uri.file(coverPath).toString()
          : (coverPath ?? old.albumCoverUrl),
      filePath: old.filePath,
      duration: meta.durationMs > 0 ? (meta.durationMs / 1000).round() : old.duration,
      coverData: meta.albumArt,
      mediaStoreId: old.mediaStoreId,
      size: old.size,
      bitrate: meta.bitrate ?? old.bitrate,
      codec: old.codec,
      lyrics: meta.lyrics ?? old.lyrics,
      qualities: old.qualities,
    );

    _songs[idx] = updated;
    _applyFilterAndSort();
    notifyListeners();
  }

  void search(String query) {
    _searchQuery = query;
    _applyFilterAndSort();
    notifyListeners();
  }

  void sortBy(String field) {
    if (_sortField == field) {
      _sortAscending = !_sortAscending;
    } else {
      _sortField = field;
      _sortAscending = true;
    }
    _applyFilterAndSort();
    notifyListeners();
  }

  void _applyFilterAndSort() {
    var result = _songs.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final artist = s.artists.isNotEmpty ? s.artists.first : '';
      return s.name.toLowerCase().contains(q) ||
          artist.toLowerCase().contains(q) ||
          (s.albumName?.toLowerCase().contains(q) ?? false);
      }).toList();

      result.sort((a, b) {
        int cmp;
        switch (_sortField) {
          case 'artist':
            final artistA = a.artists.isNotEmpty ? a.artists.first : '';
            final artistB = b.artists.isNotEmpty ? b.artists.first : '';
            cmp = artistA.compareTo(artistB);
            break;
          case 'album':
            cmp = (a.albumName ?? '').compareTo(b.albumName ?? '');
            break;
          case 'duration':
            cmp = a.duration.compareTo(b.duration);
            break;
          default: // 'title'
            cmp = a.name.compareTo(b.name);
        }
        return _sortAscending ? cmp : -cmp;
      });

    _filteredSongs = result;
  }

  // ── Grouped views ──

  /// 按专辑分组（用于分 Tab 浏览）。
  /// 返回排序后的 Entry 列表，每个 Entry 含专辑名、封面、歌曲列表。
  List<LocalGroupEntry> groupedByAlbum() {
    final map = <String, List<Song>>{};
    for (final s in _songs) {
      final key = s.albumName ?? '未知专辑';
      map.putIfAbsent(key, () => []).add(s);
    }
    final list = map.entries
        .map((e) => LocalGroupEntry(
              title: e.key,
              count: e.value.length,
              songs: e.value,
              thumbnail: _findThumbnail(e.value),
            ))
        .toList();
    list.sort((a, b) => a.title.compareTo(b.title));
    return list;
  }

  /// 按歌手分组。
  List<LocalGroupEntry> groupedByArtist() {
    final map = <String, List<Song>>{};
    for (final s in _songs) {
      final key = s.artists.isNotEmpty ? s.artists.first : '未知歌手';
      map.putIfAbsent(key, () => []).add(s);
    }
    final list = map.entries
        .map((e) => LocalGroupEntry(
              title: e.key,
              count: e.value.length,
              songs: e.value,
              thumbnail: _findThumbnail(e.value),
            ))
        .toList();
    list.sort((a, b) => a.title.compareTo(b.title));
    return list;
  }

  /// 按文件夹分组（截取父目录名）。
  List<LocalGroupEntry> groupedByFolder() {
    final map = <String, List<Song>>{};
    for (final s in _songs) {
      final fp = s.filePath;
      if (fp == null) continue;
      final parent = fp.contains('/')
          ? fp.substring(0, fp.lastIndexOf('/'))
          : '/';
      final folderName = parent.contains('/')
          ? parent.substring(parent.lastIndexOf('/') + 1)
          : parent;
      final key = folderName.isEmpty ? '根目录' : folderName;
      map.putIfAbsent(key, () => []).add(s);
    }
    final list = map.entries
        .map((e) => LocalGroupEntry(
              title: e.key,
              count: e.value.length,
              songs: e.value,
              thumbnail: _findThumbnail(e.value),
            ))
        .toList();
    list.sort((a, b) => a.title.compareTo(b.title));
    return list;
  }

  static String? _findThumbnail(List<Song> songs) {
    for (final s in songs) {
      if (s.albumCoverUrl != null && s.albumCoverUrl!.isNotEmpty) {
        return s.albumCoverUrl;
      }
    }
    return null;
  }

  // ── Directory management ──

  Future<List<String>> getSearchDirs() => _service.getPersistedDirs();

  Future<void> addSearchDir(String path) async {
    await _service.addSearchDir(path);
    await scanMusic();
  }

  Future<void> removeSearchDir(String path) async {
    await _service.removeSearchDir(path);
    await scanMusic();
  }
}

/// 分组条目：用于按专辑/歌手/文件夹浏览本地音乐。
class LocalGroupEntry {
  final String title;
  final int count;
  final List<Song> songs;
  final String? thumbnail;

  const LocalGroupEntry({
    required this.title,
    required this.count,
    required this.songs,
    this.thumbnail,
  });
}

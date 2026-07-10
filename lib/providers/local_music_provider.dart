import 'package:flutter/foundation.dart';
import '../models/local_song.dart';
import '../models/song.dart';
import '../services/local_music_service.dart';
import '../services/metadata_reader.dart';
import '../utils/logger.dart';

class LocalMusicProvider extends ChangeNotifier {
  final LocalMusicService _service = LocalMusicService();

  // State
  List<LocalSong> _songs = [];
  List<LocalSong> get songs => _filteredSongs;
  List<LocalSong> _filteredSongs = [];

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
  Future<void> scanMusic() async {
    if (_isScanning) return;
    _isScanning = true;
    _error = null;
    _status = '正在扫描...';
    notifyListeners();
    try {
      final songs = await _service.scanMusic();
      // Dedup by filePath
      final seen = <String>{};
      _songs = [];
      for (final s in songs) {
        if (seen.add(s.filePath)) _songs.add(s);
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

  /// 按需加载嵌入封面和歌词（非阻塞）。
  ///
  /// 当用户点击歌曲或进入播放器时调用，读取完整封面并缓存到磁盘。
  Future<void> loadDeferredMetadata(LocalSong song) async {
    final meta = await MetadataReader.readDeferred(song);
    if (meta == null) return;

    // 原地更新 _songs 中的条目
    final idx = _songs.indexWhere((s) => s.filePath == song.filePath);
    if (idx == -1) return;

    // 使用 MMR 返回的数据构建更新后的 LocalSong
    final coverPath = meta.albumCoverCachePath ??
        await MetadataReader.cachedCoverPath(song.filePath) ??
        song.albumCoverPath;

    final updated = LocalSong(
      title: song.title,
      artist: song.artist,
      album: song.album,
      filePath: song.filePath,
      size: song.size,
      duration: meta.durationMs > 0 ? (meta.durationMs / 1000).round() : song.duration,
      bitrate: meta.bitrate ?? song.bitrate,
      codec: song.codec,
      lyrics: meta.lyrics ?? song.lyrics,
      albumCoverPath: coverPath,
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
      return s.displayName.toLowerCase().contains(q) ||
          (s.artist?.toLowerCase().contains(q) ?? false) ||
          (s.album?.toLowerCase().contains(q) ?? false);
    }).toList();

    result.sort((a, b) {
      int cmp;
      switch (_sortField) {
        case 'artist':
          cmp = (a.artist ?? '').compareTo(b.artist ?? '');
          break;
        case 'album':
          cmp = (a.album ?? '').compareTo(b.album ?? '');
          break;
        case 'duration':
          cmp = a.duration.compareTo(b.duration);
          break;
        default: // 'title'
          cmp = a.displayName.compareTo(b.displayName);
      }
      return _sortAscending ? cmp : -cmp;
    });

    _filteredSongs = result;
  }

  static Map<String, String> _buildQualityMap(LocalSong s) {
    final q = <String, String>{};
    if (s.codec == 'FLAC' || s.codec == 'WAV') {
      q['flac'] = s.filePath;
    } else if (s.bitrate != null && s.bitrate! >= 320) {
      q['320'] = s.filePath;
    } else {
      q['128'] = s.filePath;
    }
    return q;
  }

  static Song localSongToSong(LocalSong s) {
    return Song(
      // 负数空间避免与在线歌曲 ID（始终为正）冲突
      id: -(s.filePath.hashCode),
      name: s.displayName,
      artists: [s.artist ?? '本地音乐'],
      albumName: s.album,
      albumCoverUrl: s.albumCoverPath != null
          ? Uri.file(s.albumCoverPath!).toString()
          : null,
      coverData: null, // 改为按需加载（见 loadDeferredMetadata）
      filePath: s.filePath,
      duration: s.duration,
      qualities: _buildQualityMap(s),
      lyrics: s.lyrics,
    );
  }

  List<Song> toSongList() => _filteredSongs.map(localSongToSong).toList();

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

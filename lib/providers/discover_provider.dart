import 'package:flutter/foundation.dart';
import '../models/radio.dart';
import '../models/playlist.dart';
import '../models/rank_entry.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../models/song_mapper.dart';
import '../models/scene_category.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../constants/discover_constants.dart';

/// 发现页状态管理
///
/// 替代原来 _DiscoverScreenState 中的 15 个 List 字段，
/// 统一管理所有区块数据、加载状态、错误处理。
class DiscoverProvider extends ChangeNotifier {
  final MusicService _musicService;

  DiscoverProvider(this._musicService);

  // ─── 数据 ───

  List<RadioStation> _fmList = [];
  List<Playlist> _topPlaylists = [];
  List<RankEntry> _rankList = [];
  List<Song> _topSongs = [];
  List<Album> _topAlbums = [];
  List<SceneCategory> _sceneCategories = [];
  List<Map<String, dynamic>> _ipList = [];
  List<Song> _personalFmSongs = [];
  // ─── 状态 ───

  bool _loading = true;
  String? _error;

  // ─── Getters ───

  List<RadioStation> get fmList => _fmList;
  List<Playlist> get topPlaylists => _topPlaylists;
  List<RankEntry> get rankList => _rankList;
  List<Song> get topSongs => _topSongs;
  List<Album> get topAlbums => _topAlbums;
  List<SceneCategory> get sceneCategories => _sceneCategories;
  List<Map<String, dynamic>> get ipList => _ipList;
  List<Song> get personalFmSongs => _personalFmSongs;
  bool get loading => _loading;
  String? get error => _error;

  bool get hasPlaylists => _topPlaylists.isNotEmpty;
  bool get hasRanks => _rankList.isNotEmpty;
  bool get hasTopSongs => _topSongs.isNotEmpty;
  bool get hasTopAlbums => _topAlbums.isNotEmpty;
  bool get hasScenes => _sceneCategories.isNotEmpty;
  bool get hasIp => _ipList.isNotEmpty;
  bool get hasFm => _fmList.isNotEmpty;
  bool get hasPersonalFm => _personalFmSongs.isNotEmpty;

  // ─── 加载 ───

  /// 加载全部发现数据（首屏 + 下拉刷新）
  Future<void> loadAll() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadFm(),
        _loadPlaylists(),
        _loadRanks(),
        _loadTopSongs(),
        _loadTopAlbums(),
        _loadSceneCategories(),
        _loadIp(),
        _loadPersonalFm(),
      ]);
    } catch (e, s) {
      Log.e('DiscoverProvider', 'loadAll error', e, s);
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> _loadFm() async {
    try {
      final fm = await _musicService.getFmRecommend();
      _fmList = fm.take(DiscoverConstants.fmLimit).toList();
    } catch (e, s) {
      Log.e('DiscoverProvider', 'loadFm error', e, s);
    }
  }

  Future<void> _loadPlaylists() async {
    try {
      _topPlaylists =
          await _musicService.getTopPlaylists(limit: DiscoverConstants.playlistLimit);
    } catch (e, s) {
      Log.e('DiscoverProvider', 'loadPlaylists error', e, s);
    }
  }

  Future<void> _loadRanks() async {
    try {
      final ranks = await _musicService.getRankList();
      _rankList = ranks.take(DiscoverConstants.rankLimit).toList();
    } catch (e, s) {
      Log.e('DiscoverProvider', 'loadRanks error', e, s);
    }
  }

  Future<void> _loadTopSongs() async {
    try {
      final songs = await _musicService.getTopSongs();
      _topSongs = songs.take(DiscoverConstants.topSongsLimit).toList();
    } catch (e, s) {
      Log.e('DiscoverProvider', 'loadTopSongs error', e, s);
    }
  }

  Future<void> _loadTopAlbums() async {
    try {
      _topAlbums = await _musicService.getTopAlbums(
        pageSize: DiscoverConstants.topAlbumsPageSize,
      );
    } catch (e, s) {
      Log.e('DiscoverProvider', 'loadTopAlbums error', e, s);
    }
  }

  Future<void> _loadSceneCategories() async {
    try {
      final scenes = await _musicService.getSceneLists();
      _sceneCategories = scenes.take(DiscoverConstants.sceneLimit).toList();
    } catch (e, s) {
      Log.e('DiscoverProvider', 'loadSceneCategories error', e, s);
    }
  }

  Future<void> _loadIp() async {
    try {
      final ip = await _musicService.getTopIp();
      _ipList = ip.take(DiscoverConstants.ipLimit).toList();
    } catch (e, s) {
      Log.e('DiscoverProvider', 'loadIp error', e, s);
    }
  }

  Future<void> _loadPersonalFm() async {
    try {
      final raw = await _musicService.getPersonalFm();
      _personalFmSongs = raw
          .map((e) => SongMapper.fromTrackJson(e as Map<String, dynamic>))
          .whereType<Song>()
          .take(DiscoverConstants.topSongsLimit)
          .toList();
    } catch (e, s) {
      Log.e('DiscoverProvider', 'loadPersonalFm error', e, s);
    }
  }

}

// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/models/local_song.dart';
import 'package:ngskg_plus/models/playlist.dart';
import 'package:ngskg_plus/models/rank_entry.dart';
import 'package:ngskg_plus/models/song.dart';
import 'package:ngskg_plus/models/user.dart';
import 'package:ngskg_plus/providers/audio_settings_provider.dart';
import 'package:ngskg_plus/providers/auth_provider.dart';
import 'package:ngskg_plus/providers/liked_songs_provider.dart';
import 'package:ngskg_plus/providers/local_music_provider.dart';
import 'package:ngskg_plus/providers/player_provider.dart';
import 'package:ngskg_plus/providers/playlist_provider.dart';
import 'package:ngskg_plus/services/auth_service.dart';
import 'package:ngskg_plus/services/music_service.dart';
import 'package:provider/provider.dart';

// All media, accounts and file names here are synthetic. No URL is supplied:
// album art uses the production widget's own missing-cover state.
const gallerySongs = [
  Song(id: 1, name: '星光', artists: ['小夜'], albumName: '夜航'),
  Song(id: 2, name: '微风', artists: ['山川'], albumName: '晴天'),
  Song(id: 3, name: '海岸', artists: ['小夜'], albumName: '夜航'),
];
const galleryPlaylist = Playlist(id: 18, name: '夜跑歌单', trackCount: 3);
const galleryRank = RankEntry(id: 7, name: '新歌榜');

class GalleryPlayer extends Fake with ChangeNotifier implements PlayerProvider {
  @override
  List<Song> playlist = gallerySongs;
  @override
  int currentIndex = 0;
  @override
  Song? get currentSong => playlist.isEmpty ? null : playlist[currentIndex];
  @override
  bool isPlaying = false;
  @override
  bool isFmMode = false;
  @override
  PlayMode playMode = PlayMode.sequential;
  @override
  final lyricController = LyricController();
  @override
  Null get palette => null;
  @override
  Duration get position => const Duration(seconds: 44);
  @override
  Duration get duration => const Duration(seconds: 176);
  @override
  double get progress => 0.25;

  @override
  Future<void> playIndex(int index) async {
    currentIndex = index;
    isPlaying = true;
    notifyListeners();
  }

  @override
  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    this.playlist = playlist ?? [song];
    await playIndex(this.playlist.indexWhere((entry) => entry.id == song.id));
  }

  @override
  void playPrevious() => playIndex((currentIndex - 1) % playlist.length);
  @override
  void playNext() => playIndex((currentIndex + 1) % playlist.length);
  @override
  Future<void> togglePlayPause() async {
    isPlaying = !isPlaying;
    notifyListeners();
  }

  @override
  void setPlayMode(PlayMode mode) {
    playMode = mode;
    notifyListeners();
  }

  @override
  void startFmPlaylist(
    List<Song> songs, {
    required Future<List<Song>> Function() bufferProvider,
    VoidCallback? onDislike,
    void Function(Song song, {int playtime})? onPlaybackUpdate,
  }) {
    isFmMode = true;
    playlist = songs;
    playIndex(0);
  }

  @override
  void dispose() {
    lyricController.dispose();
    super.dispose();
  }
}

class GalleryAuth extends Fake with ChangeNotifier implements AuthProvider {
  @override
  User? user = const User(userId: 42, nickname: '小夜');
  @override
  bool get isLoggedIn => user != null;
  @override
  Future<void> sendCaptcha(String phone) async {}
  @override
  Future<bool> loginWithPhone(String phone, String code) async => false;
}

class GalleryLikes extends Fake
    with ChangeNotifier
    implements LikedSongsProvider {
  @override
  List<Song> likedSongs = List.of(gallerySongs);
  @override
  Set<int> get likedIds => likedSongs.map((s) => s.id).toSet();
  @override
  bool get isLoaded => true;
  @override
  Future<void> load() async {}
  @override
  Future<bool> toggle(SongInfo song) async {
    likedSongs.removeWhere((s) => s.id == song.id);
    notifyListeners();
    return true;
  }
}

class GalleryPlaylists extends Fake
    with ChangeNotifier
    implements PlaylistProvider {
  @override
  List<Playlist> get userPlaylists => const [
    galleryPlaylist,
    Playlist(id: 19, name: '午后散步', trackCount: 2),
  ];
  @override
  PlaylistDetail? currentPlaylist;
  @override
  Future<void> fetchUserPlaylist(int? userId) async {}
  @override
  Future<void> fetchPlaylistDetail(String id) async {
    if (id != galleryPlaylist.id.toString()) throw StateError('未知样本歌单');
    currentPlaylist = const PlaylistDetail(
      playlist: galleryPlaylist,
      songs: gallerySongs,
    );
    notifyListeners();
  }
}

class GalleryLocal extends Fake
    with ChangeNotifier
    implements LocalMusicProvider {
  @override
  bool get scanned => true;
  @override
  String? get error => null;
  @override
  bool isScanning = false;
  @override
  List<LocalSong> songs = const [
    LocalSong(
      title: '林间',
      artist: '山川',
      album: '晨雾',
      filePath: '/fixture/forest.flac',
    ),
    LocalSong(
      title: '清晨',
      artist: '小夜',
      album: '日出',
      filePath: '/fixture/morning.mp3',
    ),
  ];
  @override
  List<Song> toSongList() =>
      songs.map(LocalMusicProvider.localSongToSong).toList();
  @override
  Future<void> scanMusic() async {}
}

class GalleryQuality extends Fake
    with ChangeNotifier
    implements AudioSettingsProvider {
  @override
  String wifiQuality = '320';
  @override
  Future<void> setWifiQuality(String key) async {
    wifiQuality = key;
    notifyListeners();
  }
}

class GalleryMusic extends Fake implements MusicService {
  Completer<List<Song>>? pendingSearch;
  Completer<List<RankEntry>>? pendingRanks;
  Completer<List<Song>>? pendingRankSongs;
  Completer<List<Map<String, dynamic>>>? pendingFm;
  @override
  Future<List<Song>> search(
    String keyword, {
    int limit = 30,
    int offset = 0,
    String type = 'song',
  }) async {
    if (keyword == '等待') return pendingSearch!.future;
    if (keyword == '断线') throw const FormatException('连接中断');
    return gallerySongs
        .where(
          (s) => s.name.contains(keyword) || s.artistDisplay.contains(keyword),
        )
        .toList();
  }

  @override
  Future<List<RankEntry>> getRankList() =>
      pendingRanks?.future ??
      Future.value(const [galleryRank, RankEntry(id: 8, name: '热歌榜')]);
  @override
  Future<List<Song>> getRankAudios(
    int rankId, {
    int page = 1,
    int pageSize = 200,
    int? rankCid,
  }) => pendingRankSongs?.future ?? Future.value(gallerySongs);
  @override
  Future<List<Map<String, dynamic>>> getPersonalFm({
    String mode = 'normal',
    int songPoolId = 0,
    String? hash,
    int? songid,
    int? playtime,
    String? action,
    int? isOverplay,
    int? remainSongcnt,
  }) =>
      pendingFm?.future ??
      Future.value(const [
        {'id': 11, 'songname': '海风', 'author_name': '山川'},
        {'id': 12, 'songname': '潮声', 'author_name': '小夜'},
      ]);
}

class GalleryQr extends Fake implements AuthService {
  int status = 1;
  @override
  Future<Map<String, dynamic>> getQrKey() async => {'key': 'gallery-only'};
  @override
  Future<Map<String, dynamic>> getQrCreate(
    String key, {
    bool qrimg = false,
  }) async => {'qrimg': qrPng};
  @override
  Future<Map<String, dynamic>> checkQrStatus(String key) async => {
    'data': status,
  };
  // Offline fixture. Its encoded text has no login or account information.
  static const qrPng =
      'iVBORw0KGgoAAAANSUhEUgAAAFcAAABXAQAAAABZs+TBAAAAyUlEQVR4nM2TMQ6CQBBF/wgJNmYvQAJXsKNbOq+jXoDQcSU7qPYaJF6ApcIE91sYY7VDqVNN8fL/zPyMEJ/iDt/6VQ9OwMXlQBHivHDFEQ1VzaHkafT7DV/Tbc/m63KDsaO5wSwaQ0nnDK3EmRSGwCOhkgXoFwgT38fvA05VEbJcSIWhWxvHYDXGL2wX0mleARDHCaoXOQEN1ZmBsy2oMDsIV2mfph43cq+BodQzlT65WlUHODQDW1XHjtJhruI6771w1+4jf/aDLy+XZn43MV8KAAAAAElFTkSuQmCC';
}

class GalleryFixtures {
  final player = GalleryPlayer();
  final auth = GalleryAuth();
  final likes = GalleryLikes();
  final local = GalleryLocal();
  final music = GalleryMusic();
  final qr = GalleryQr();

  Widget wrap(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider<PlayerProvider>.value(value: player),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<LikedSongsProvider>.value(value: likes),
      ChangeNotifierProvider<LocalMusicProvider>.value(value: local),
      ChangeNotifierProvider<PlaylistProvider>(
        create: (_) => GalleryPlaylists(),
      ),
      ChangeNotifierProvider<AudioSettingsProvider>(
        create: (_) => GalleryQuality(),
      ),
      Provider<MusicService>.value(value: music),
      Provider<AuthService>.value(value: qr),
    ],
    child: child,
  );

  void dispose() {
    player.dispose();
    auth.dispose();
    likes.dispose();
    local.dispose();
  }
}

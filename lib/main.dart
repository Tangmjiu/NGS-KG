// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Watch OS entry point — Wear OS 手表版 Flutter 入口
// Build: flutter build apk --debug  (或 --release)

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/player_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/liked_songs_provider.dart';
import 'services/api_client.dart';
import 'services/music_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/cache_service.dart';
import 'services/device_service.dart';
import 'providers/audio_settings_provider.dart';
import 'providers/local_music_provider.dart';
import 'utils/logger.dart';
import 'utils/navigation.dart';

import 'watch/app.dart';
import 'watch/theme/watch_theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Log.init();

  FlutterError.onError = (details) {
    try {
      Log.e('WATCH', details.exceptionAsString(), details.exception, details.stack);
    } catch (_) {
      debugPrint('WATCH_ERROR: ${details.exceptionAsString()}');
    }
    FlutterError.dumpErrorToConsole(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    try {
      Log.e('WATCH_PLATFORM', error.toString(), error, stack);
    } catch (_) {
      debugPrint('WATCH_PLATFORM_ERROR: $error');
    }
    return true;
  };

  // 精简版异常渲染页面（适合小屏）
  ErrorWidget.builder = (details) {
    debugPrint('WATCH_RENDER_ERROR: ${details.exceptionAsString()}');
    return Material(
      color: const Color(0xFF1E1E1E),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Σ(°△°)︴',
            style: const TextStyle(color: Colors.white38, fontSize: 24),
          ),
        ),
      ),
    );
  };

  runZonedGuarded(() {
    _initDevice();
    _initNotifications();
  }, (error, stack) {
    Log.e('WATCH_ZONE', 'Background init error', error, stack);
  });

  CacheService.instance.init();
  final musicService = MusicService();
  final authService = AuthService();
  final audioSettings = AudioSettingsProvider()..init();
  final watchThemeProvider = WatchThemeProvider()..init();
  final likedSongs = LikedSongsProvider(musicService);
  final authProvider = AuthProvider(authService, likedSongs: likedSongs);

  unawaited(authProvider.ready.then((_) {
    Log.i('watch_main', 'AuthProvider ready, user=${authProvider.isLoggedIn}');
    if (authProvider.isLoggedIn) likedSongs.load();
  }));

  runApp(
    MultiProvider(
      providers: [
        Provider<MusicService>.value(value: musicService),
        Provider<AuthService>.value(value: authService),
        ChangeNotifierProvider.value(value: audioSettings),
        ChangeNotifierProvider.value(value: watchThemeProvider),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => PlayerProvider(
          musicService,
          audioSettings: audioSettings,
          likedSongs: likedSongs,
        )),
        ChangeNotifierProvider(create: (_) => PlaylistProvider(musicService)),
        ChangeNotifierProvider.value(value: likedSongs),
        ChangeNotifierProvider(create: (_) => LocalMusicProvider()),
      ],
      child: const NGSKGWearApp(),
    ),
  );
}

Future<void> _initDevice() async {
  try {
    final device = await DeviceService.instance.getDeviceInfo();
    if (device == null || !device.isValid) {
      final newDevice = await DeviceService.instance.registerDevice();
      ApiClient.setDfid(newDevice.dfid);
    } else {
      ApiClient.setDfid(device.dfid);
    }
  } catch (_) {}
}

Future<void> _initNotifications() async {
  final notif = NotificationService.instance;
  await notif.init();
  notif.onNotificationTap = () {};
  notif.onPrev = () => _notifAction('prev');
  notif.onPlayPause = () => _notifAction('play_pause');
  notif.onNext = () => _notifAction('next');
  notif.onLike = () => _notifAction('like');
  notif.onSwitchMode = () => _notifAction('switch_mode');
  notif.onSeekTo = (posMs) {
    final ctx = navKey.currentState?.overlay?.context;
    if (ctx == null) return;
    ctx.read<PlayerProvider>().seek(Duration(milliseconds: posMs));
  };
}

void _notifAction(String action) {
  final ctx = navKey.currentState?.overlay?.context;
  if (ctx == null) return;
  final player = ctx.read<PlayerProvider>();
  switch (action) {
    case 'prev':
      player.playPrevious();
    case 'play_pause':
      player.togglePlayPause();
    case 'next':
      player.playNext();
    case 'like':
      final song = player.currentSong;
      if (song != null) {
        ctx.read<LikedSongsProvider>().toggle(SongInfo(
        id: song.id,
        name: song.name,
        hash: song.hash ?? '',
        albumId: song.albumId,
        audioId: 0,
      ));
      }
    case 'switch_mode':
      final modes = [PlayMode.sequential, PlayMode.shuffle, PlayMode.repeatOne];
      final next = modes[(modes.indexOf(player.playMode) + 1) % modes.length];
      player.setPlayMode(next);
  }
}

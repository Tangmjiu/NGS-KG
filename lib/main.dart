// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/player_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/liked_songs_provider.dart';
import 'providers/discover_provider.dart';
import 'routes/app_routes.dart';
import 'screens/settings_screen.dart';
import 'utils/logger.dart';
import 'services/api_client.dart';
import 'providers/theme_provider.dart';
import 'widgets/desktop_shell.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'services/device_service.dart';
import 'services/music_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/cache_service.dart';
import 'services/desktop_service.dart';
import 'providers/audio_settings_provider.dart';
import 'utils/preview_config.dart';
import 'theme/theme_assets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'utils/navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化跨平台 SQLite（Windows 需 FFI�?
  sqfliteFfiInit();

  await Log.init();

  FlutterError.onError = (details) {
    try {
      Log.e('FLUTTER', details.exceptionAsString(), details.exception,
          details.stack);
    } catch (_) {
      debugPrint('FLUTTER_ERROR: ${details.exceptionAsString()}');
    }
    FlutterError.dumpErrorToConsole(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    try {
      Log.e('PLATFORM', error.toString(), error, stack);
    } catch (_) {
      debugPrint('PLATFORM_ERROR: $error');
    }
    return true;
  };

  ErrorWidget.builder = (details) {
    debugPrint('RENDER_ERROR: ${details.exceptionAsString()}');
    try {
      Log.e('RENDER', details.exceptionAsString(), details.exception,
          details.stack);
    } catch (_) {}
    return Material(
      color: const Color(0xFF1E1E1E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              ThemeAssets.codecrash,
              width: 80,
              height: 80,
              errorBuilder: (_, __, ___) => const Icon(Icons.error_outline, size: 64, color: Colors.white38),
            ),
            const SizedBox(height: 16),
            const Text(
              '渲染异常',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  };

  // 只对后台初始化任务使�?zone 捕获异常
  runZonedGuarded(() {
    _initDevice();
    _initNotifications();
  }, (error, stack) {
    Log.e('ZONE', 'Background init error', error, stack);
  });

  await PreviewConfig.load();
  CacheService.instance.init();
  final musicService = MusicService();
  final authService = AuthService();
  final audioSettings = AudioSettingsProvider()..init();
  final themeProvider = ThemeProvider()..init();
  final likedSongs = LikedSongsProvider(musicService);
  // 先初始化认证（从本地文件加载），避免 auth 准备就绪�?PlayerProvider 发起网络请求
  final authProvider = AuthProvider(authService, likedSongs: likedSongs);
  // 小延迟确保文件读取完成；ready �?_loadSavedUser() 完成后触�?
  unawaited(authProvider.ready.then((_) {
    Log.i('main', 'AuthProvider ready, user=${authProvider.isLoggedIn}');
  }));
  // 注意：此处不能阻�?runApp —�?authProvider 在构造时已启�?_loadSavedUser()
  // apiClient.setAuth �?_loadSavedUser 内调用，PlayerProvider �?restorePlaybackState
  // �?addPostFrameCallback 调度，通常�?auth 就绪之后才执行�?
  runApp(
    MultiProvider(
      providers: [
        Provider<MusicService>.value(value: musicService),
        Provider<AuthService>.value(value: authService),
        ChangeNotifierProvider.value(value: audioSettings),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => PlayerProvider(musicService,
            audioSettings: audioSettings,
            likedSongs: likedSongs,
        )),
        ChangeNotifierProvider(create: (_) => PlaylistProvider(musicService)),
        ChangeNotifierProvider.value(value: likedSongs),
        ChangeNotifierProvider(create: (_) => DiscoverProvider(musicService)),
      ],
      child: const NGSKGApp(),
    ),
  );

  // 桌面端初始化（SMTC / 托盘 / 窗口管理�?
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initDesktopServices();
  });
}

Future<void> _initDesktopServices() async {
  try {
    final ctx = navKey.currentContext;
    if (ctx == null) return;
    final player = ctx.read<PlayerProvider>();
    await DesktopService.instance.init(player);

    // 监听播放器状�?�?同步桌面服务
    player.addListener(() {
      String? lyricText;
      final idx = player.lyricController.activeIndexNotifiter.value;
      final model = player.lyricController.lyricNotifier.value;
      final lines = model?.lines ?? [];
      if (idx >= 0 && idx < lines.length) {
        final line = lines[idx];
        lyricText = line.text;
        if (line.translation != null && line.translation!.isNotEmpty) {
          lyricText = '$lyricText / ${line.translation}';
        }
      }
      DesktopService.instance.sync(
        song: player.currentSong,
        isPlaying: player.isPlaying,
        positionMs: player.position.inMilliseconds,
        durationMs: player.duration.inMilliseconds,
        lyricText: lyricText,
      );
    });
  } catch (e) {
    debugPrint('DesktopService init: $e');
  }
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
        ));
      }
    case 'switch_mode':
      final modes = [PlayMode.sequential, PlayMode.shuffle, PlayMode.repeatOne];
      final next = modes[(modes.indexOf(player.playMode) + 1) % modes.length];
      player.setPlayMode(next);
  }
}

class NGSKGApp extends StatelessWidget {
  const NGSKGApp({super.key});

  @override
  Widget build(BuildContext context) {
    // DynamicColorBuilder �?Android 12+ 可用，其他平台传 null
    if (Platform.isAndroid) {
      return DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) {
          return _buildApp(lightDynamic, darkDynamic);
        },
      );
    }
    return _buildApp(null, null);
  }

  Widget _buildApp(ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          navigatorKey: navKey,
          title: 'NGS-KG+',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.buildLightTheme(context, dynamicScheme: lightDynamic),
          darkTheme: themeProvider.buildDarkTheme(context, dynamicScheme: darkDynamic),
          themeMode: themeProvider.themeMode,
          initialRoute: AppRoutes.home,
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.settings) {
              return MaterialPageRoute(
                builder: (_) => const SettingsScreen(),
              );
            }
            return AppRoutes.generateRoute(settings);
          },
          builder: (context, child) {
            return Stack(
              children: [
                // ── 全局主题背景 ──
                if (ThemeAssets.playerBg.isNotEmpty)
                  Positioned.fill(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Image.file(
                        File(ThemeAssets.playerBg),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                // 桌面端直接用 DesktopShell 作为外壳
                const DesktopShell(),
              ],
            );
          },
        );
      },
    );
  }
}


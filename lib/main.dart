import 'dart:async';
import 'dart:io' show Platform;
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
import 'widgets/app_shell.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'services/device_service.dart';
import 'services/music_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/cache_service.dart';
import 'services/desktop_service.dart';
import 'providers/audio_settings_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化跨平台 SQLite（Windows 需 FFI）
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
    return const Center(
      child: Text('渲染异常', style: TextStyle(color: Colors.white70, fontSize: 16)),
    );
  };

  // 只对后台初始化任务使�?zone 捕获异常
  runZonedGuarded(() {
    _initDevice();
    _initNotifications();
  }, (error, stack) {
    Log.e('ZONE', 'Background init error', error, stack);
  });

  CacheService.instance.init();
  final musicService = MusicService();
  final authService = AuthService();
  final audioSettings = AudioSettingsProvider()..init();
  final themeProvider = ThemeProvider()..init();
  runApp(
    MultiProvider(
      providers: [
        Provider<MusicService>.value(value: musicService),
        Provider<AuthService>.value(value: authService),
        ChangeNotifierProvider.value(value: audioSettings),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)),
        ChangeNotifierProvider(create: (_) => PlayerProvider(musicService, audioSettings: audioSettings)),
        ChangeNotifierProvider(create: (_) => PlaylistProvider(musicService)),
        ChangeNotifierProvider(create: (_) => LikedSongsProvider(musicService)),
        ChangeNotifierProvider(create: (_) => DiscoverProvider(musicService)),
      ],
      child: const NGSKGApp(),
    ),
  );

  // 桌面端初始化（SMTC / 托盘 / 窗口管理）
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

    // 监听播放器状态 → 同步桌面服务
    player.addListener(() {
      DesktopService.instance.sync(
        song: player.currentSong,
        isPlaying: player.isPlaying,
        positionMs: player.position.inMilliseconds,
        durationMs: player.duration.inMilliseconds,
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
  }
}

class NGSKGApp extends StatelessWidget {
  const NGSKGApp({super.key});

  @override
  Widget build(BuildContext context) {
    // DynamicColorBuilder 仅 Android 12+ 可用，其他平台传 null
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
            return AppShell(child: child);
            },
      );
    },
  );
  }
}

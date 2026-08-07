// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'providers/auth_provider.dart';
import 'providers/player_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/liked_songs_provider.dart';
import 'providers/discover_provider.dart';
import 'routes/app_routes.dart';
import 'utils/logger.dart';
import 'services/api_client.dart';
import 'providers/theme_provider.dart';
import 'widgets/app_shell.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'services/device_service.dart';
import 'services/music_service.dart';
import 'services/auth_service.dart';
import 'services/api_config.dart';
import 'services/audio_handler.dart';
import 'services/cache_service.dart';
import 'services/remote_config_service.dart';
import 'providers/audio_settings_provider.dart';
import 'navidrome/navidrome_provider.dart';
import 'providers/local_music_provider.dart';
import 'features/developer/debug_prefs_provider.dart';
import 'features/developer/monitors/fps_monitor.dart';
import 'utils/preview_config.dart';
import 'theme/theme_assets.dart';
import 'utils/navigation.dart';
import 'services/intent_handler_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    return LayoutBuilder(
      builder: (context, constraints) {
        // 如果在受限高度组件（如 64dp 的 MiniPlayer 或单行小控件）中出现暂时性排版或 Hero 转场闪动，
        // 绝不可强行塞入 160+dp 的巨型黑卡，以免引发大面积黑框遮挡与二次严重的 RenderFlex Overflow。
        if (constraints.maxHeight < 120 || !constraints.hasBoundedHeight) {
          return Material(
            color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: constraints.hasBoundedHeight
                  ? constraints.maxHeight.clamp(20.0, 64.0)
                  : 64.0,
              child: const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 18, color: Colors.white38),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '轻微渲染闪过',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

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
                  errorBuilder: (_, __, ___) => const Icon(Icons.error_outline,
                      size: 64, color: Colors.white38),
                ),
                const SizedBox(height: 16),
                const Text(
                  '渲染异常',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
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
      },
    );
  };

  // ─── 初始化 AudioService（替代原生 PlaybackService + MediaSession） ───
  final audioHandler = await AudioService.init<MusicAudioHandler>(
    builder: () => MusicAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.mjiutang.ngskg.audio',
      androidNotificationChannelName: '音乐播放',
      androidNotificationChannelDescription: '音乐播放控制（支持锁屏、蓝牙）',
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidShowNotificationBadge: false,
      androidNotificationClickStartsActivity: true,
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
      artDownscaleWidth: 512,
      artDownscaleHeight: 512,
      preloadArtwork: true,
    ),
  );
  // 监听原生端异步错误（PlatformException 等）
  AudioService.asyncError.listen((error) {
    Log.e('audio_service', 'asyncError', error);
  });
  // 系统控制回调 → PlayerProvider（通过 navKey 获取 context）
  audioHandler.onPlay = () => _notifAction('play_pause');
  audioHandler.onPause = () => _notifAction('play_pause');
  audioHandler.onSkipNext = () => _notifAction('next');
  audioHandler.onSkipPrevious = () => _notifAction('prev');
  audioHandler.onSeek = (pos) {
    final ctx = navKey.currentState?.overlay?.context;
    if (ctx == null) return;
    ctx.read<PlayerProvider>().seek(pos);
  };
  audioHandler.onStop = () {}; // BaseAudioHandler.stop() 自动清理通知
  audioHandler.onLike = () => _notifAction('like');
  audioHandler.onSwitchMode = () => _notifAction('switch_mode');

  // 后台任务（非阻塞）：先拉取远程配置，再初始化设备和 API 客户端
  runZonedGuarded(() {
    _initRemoteConfigAndDevice();
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
  // 先初始化认证（从本地文件加载），避免 auth 准备就绪前 PlayerProvider 发起网络请求
  final authProvider = AuthProvider(authService, likedSongs: likedSongs);
  // 小延迟确保文件读取完成；ready 在 _loadSavedUser() 完成后触发
  unawaited(authProvider.ready.then((_) {
    Log.i('main', 'AuthProvider ready, user=${authProvider.isLoggedIn}');
    if (authProvider.isLoggedIn) likedSongs.load();
  }));
  // 注意：此处不能阻塞 runApp — authProvider 在构造时已启动 _loadSavedUser()
  // apiClient.setAuth 在 _loadSavedUser 内调用，PlayerProvider 的 restorePlaybackState
  // 通过 addPostFrameCallback 调度，通常在 auth 就绪之后才执行。
  // 开发者工具：debug/profile 构建全局启动 FPS 与卡顿检测（release 下被 tree-shake）
  // 新增功能：帧率显示 + 卡顿检测
  if (!kReleaseMode) {
    FpsMonitor.instance.start();
  }
  runApp(
    MultiProvider(
      providers: [
        Provider<MusicService>.value(value: musicService),
        Provider<AuthService>.value(value: authService),
        ChangeNotifierProvider.value(value: audioSettings),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: authProvider),
        // 新增功能：开发者工具全局调试状态（仅 Debug/Profile 构建注册）
        if (!kReleaseMode)
          ChangeNotifierProvider(create: (_) => DebugPrefsProvider()),
        ChangeNotifierProvider(
            create: (_) => PlayerProvider(
                  musicService,
                  audioHandler: audioHandler,
                  audioSettings: audioSettings,
                  likedSongs: likedSongs,
                )),
        ChangeNotifierProvider(create: (_) => PlaylistProvider(musicService)),
        ChangeNotifierProvider.value(value: likedSongs),
        ChangeNotifierProvider(create: (_) => DiscoverProvider(musicService)),
        ChangeNotifierProvider(create: (_) => NavidromeProvider()),
        ChangeNotifierProvider(create: (_) => LocalMusicProvider()),
      ],
      child: const NGSKGApp(),
    ),
  );
  // 启动外部文件打开监听（Android Intent）
  IntentHandlerService.instance.start();
  IntentHandlerService.instance.onFileOpen.listen((filePath) async {
    // 获取 LocalMusicProvider（通过 navKey 安全访问）
    final ctx0 = navKey.currentState?.overlay?.context;
    if (ctx0 == null) return;
    final localProv = ctx0.read<LocalMusicProvider>();

    // 先确保扫描完成
    if (!localProv.scanned && !localProv.isScanning) {
      await localProv.scanMusic();
    }
    final song = await localProv.addSongFromPath(filePath);
    if (song == null) return;

    // 加入播放列表并播放（重新获取 context 避免 async gap 问题）
    final playCtx = navKey.currentState?.overlay?.context;
    if (playCtx != null) {
      playCtx.read<PlayerProvider>().playSong(song, playlist: localProv.songs);
    }

    // 导航到本地音乐界面
    navKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.localMusic,
      (route) => route.settings.name == AppRoutes.home,
    );
  });
}

Future<void> _initRemoteConfigAndDevice() async {
  try {
    // 1. 先加载远程配置缓存并尝试拉取最新配置
    await RemoteConfigService.instance.init();
    await RemoteConfigService.instance.fetch();

    // 2. 远程配置拿到后，重新初始化 ApiClient 以应用新的 baseUrl
    ApiClient.instance.reinitialize();

    // 3. 探测域名路线可用性（仅日志提示，内地路线已弃用）
    await ApiConfig.instance.detectBestRoute();

    // 4. 设备注册/恢复
    final device = await DeviceService.instance.getDeviceInfo();
    if (device == null || !device.isValid) {
      final newDevice = await DeviceService.instance.registerDevice();
      ApiClient.setDfid(newDevice.dfid);
    } else {
      ApiClient.setDfid(device.dfid);
    }
  } catch (_) {}
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
    // DynamicColorBuilder：Android 12+ 可用，其他平台传 null
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
          theme: themeProvider.buildLightTheme(context,
              dynamicScheme: lightDynamic),
          darkTheme:
              themeProvider.buildDarkTheme(context, dynamicScheme: darkDynamic),
          themeMode: themeProvider.themeMode,
          initialRoute: AppRoutes.home,
          navigatorObservers: [AppRouteObserver.instance],
          onGenerateRoute: AppRoutes.generateRoute,
          builder: (context, child) {
            // 开发者工具：性能叠加层开关（debug/profile 专用；release 下短路不读取）
            // 新增功能：性能叠加层
            final showPerfOverlay = !kReleaseMode &&
                context.watch<DebugPrefsProvider>().showPerformanceOverlay;
            return Stack(
              children: [
                // ── 全局主题背景（首页/发现/搜索等页面共用） ──
                if (ThemeAssets.playerBg.isNotEmpty &&
                    File(ThemeAssets.playerBg).existsSync())
                  Positioned.fill(
                    child: ImageFiltered(
                      // 降低 sigma 以减少低端机 GPU 负载（视觉差异小）
                      imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Image.file(
                        File(ThemeAssets.playerBg),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                // AppShell 自适应外壳：桌面全宽壳 / 移动 MiniPlayer + overlays
                AppShell(child: child),
                if (showPerfOverlay)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: PerformanceOverlay.allEnabled(),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'models/song.dart';
import 'providers/auth_provider.dart';
import 'providers/player_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/liked_songs_provider.dart';
import 'providers/discover_provider.dart';
import 'routes/app_routes.dart';
import 'utils/theme.dart';
import 'screens/player_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/logger.dart';
import 'services/api_client.dart';
import 'services/device_service.dart';
import 'services/music_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/cache_service.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
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
    } catch (_) {
      // Log may not be ready during early build �?debugPrint already fired
    }
    return Container(
      color: const Color(0xFF1A1C19),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('渲染异常',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
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

  CacheService.instance.init();
  final musicService = MusicService();
  final authService = AuthService();
  runApp(
    MultiProvider(
      providers: [
        Provider<MusicService>.value(value: musicService),
        Provider<AuthService>.value(value: authService),
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)),
        ChangeNotifierProvider(create: (_) => PlayerProvider(musicService)),
        ChangeNotifierProvider(create: (_) => PlaylistProvider(musicService)),
        ChangeNotifierProvider(create: (_) => LikedSongsProvider(musicService)),
        ChangeNotifierProvider(create: (_) => DiscoverProvider(musicService)),
      ],
      child: const NGSKGApp(),
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

class NGSKGApp extends StatefulWidget {
  const NGSKGApp({super.key});
  @override
  State<NGSKGApp> createState() => _NGSKGAppState();
}

class _NGSKGAppState extends State<NGSKGApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navKey,
      title: 'NGS-KG+',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      initialRoute: AppRoutes.home,
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.settings) {
          return MaterialPageRoute(
            builder: (_) => SettingsScreen(
              currentTheme: _themeMode,
              onThemeChanged: (mode) => setState(() => _themeMode = mode),
            ),
          );
        }
        return AppRoutes.generateRoute(settings);
      },
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            Positioned(
              left: 0,
              right: 0,
              bottom: kBottomNavigationBarHeight,
              child: _PlayerBarBottom(),
            ),
            const _ContinuePlayOverlay(),
          ],
        );
      },
    );
  }
}

class _PlayerBarBottom extends StatelessWidget {
  const _PlayerBarBottom();

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (_, player, __) {
        final song = player.currentSong;
        if (song == null || player.isPlayerScreenVisible)
          return const SizedBox.shrink();
        final tt = Theme.of(context).textTheme;

        final dynamicBg = player.backgroundColor;
        // 玻璃底色：取动态色或纯�?
        final glassColor = (dynamicBg ?? const Color(0xFF1A1A1A))
            .withValues(alpha: 0.72);

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: GestureDetector(
                onTap: () {
                  player.setPlayerScreenVisible(true);
                  navKey.currentState
                      ?.push(PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const PlayerScreen(),
                        transitionsBuilder: (_, animation, __, child) {
                          return FadeTransition(
                              opacity: animation, child: child);
                        },
                        transitionDuration: const Duration(milliseconds: 300),
                      ))
                      .then((_) => player.setPlayerScreenVisible(false));
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: glassColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── 顶部分隔/进度�?──
                      if (player.duration.inMilliseconds > 0)
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          child: LinearProgressIndicator(
                            value: player.progress.isFinite
                                ? player.progress
                                : 0.0,
                            backgroundColor: Colors.white10,
                            color: Colors.white38,
                            minHeight: 2,
                          ),
                        ),
                      // ── 内容主体 ──
                      Padding(
                        padding: EdgeInsets.only(
                          left: 8,
                          right: 12,
                          top: 6,
                          bottom: MediaQuery.of(context).padding.bottom + 4,
                        ),
                        child: Row(
                          children: [
                            // 专辑封面
                            Hero(
                              tag: 'album_art_${song.hash ?? song.id}',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: song.albumCoverUrl != null &&
                                          song.albumCoverUrl!.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: song.albumCoverUrl!,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) =>
                                              _fallbackCover(
                                                  Theme.of(context)
                                                      .colorScheme),
                                          errorWidget: (_, __, ___) =>
                                              _fallbackCover(
                                                  Theme.of(context)
                                                      .colorScheme),
                                        )
                                      : _fallbackCover(
                                          Theme.of(context).colorScheme),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // 歌名 + 歌手
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(song.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: tt.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white)),
                                  const SizedBox(height: 2),
                                  Text(song.artistDisplay,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: tt.labelSmall?.copyWith(
                                          color: Colors.white70)),
                                ],
                              ),
                            ),
                            // 播放控制
                            if (player.isLoading)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white70)),
                              )
                            else ...[
                              const SizedBox(width: 4),
                              _MiniBtn(
                                icon: Icons.skip_previous,
                                size: 22,
                                onTap: player.playPrevious,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    player.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: Colors.black87,
                                    size: 22,
                                  ),
                                  onPressed: player.togglePlayPause,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _MiniBtn(
                                icon: Icons.skip_next,
                                size: 22,
                                onTap: player.playNext,
                                color: Colors.white70,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Widget _fallbackCover(ColorScheme cs) => Container(
      width: 44,
      height: 44,
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.music_note, size: 22, color: cs.onSurfaceVariant),
    );

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final Color? color;
  const _MiniBtn({required this.icon, this.size = 22, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        icon: Icon(icon, size: size, color: color),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        splashRadius: 18,
      ),
    );
  }
}

class _ContinuePlayOverlay extends StatefulWidget {
  const _ContinuePlayOverlay();
  @override
  State<_ContinuePlayOverlay> createState() => _ContinuePlayOverlayState();
}

class _ContinuePlayOverlayState extends State<_ContinuePlayOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    // 仅在登录后检查，且失败时不弹窗（静默处理）
    final authCtx = navKey.currentContext;
    if (authCtx == null) return;
    final auth = authCtx.read<AuthProvider>();
    if (!auth.isLoggedIn) return;

    try {
      // 使用直接 Dio 调用，绕过全局错误弹窗拦截器
      final client = ApiClient.instance;
      final res = await client.get('/lastest/songs/listen',
          params: {'pagesize': 1});
      if (!mounted) return;
      final data = res.data as Map<String, dynamic>? ?? {};
      final body = data['data'] as Map<String, dynamic>? ?? data;
      final songs = body['songs'] as List<dynamic>? ?? [];
      if (songs.isNotEmpty && songs[0] is Map<String, dynamic>) {
        final s = songs[0] as Map<String, dynamic>;
        if (!mounted) return;
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
                  title: const Text('继续播放'),
                  content: Text('检测到在其他设备播放了\n${s['name'] ?? ''}，是否继续？'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消')),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        final song = Song(
                          id: (s['id'] as num?)?.toInt() ?? 0,
                          name: (s['name'] as String?) ?? '',
                          artists: [(s['singer_name'] as String?) ?? ''],
                          albumCoverUrl: s['cover_url'] as String?,
                          duration: (s['duration'] as num?)?.toInt() ?? 0,
                          hash: s['hash'] as String?,
                        );
                        context.read<PlayerProvider>().playSong(song);
                      },
                      child: const Text('继续'),
                    ),
                  ],
                ));
      }
    } catch (_) {
      // 静默：继续播放接口失败不重要，不弹窗不日志
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

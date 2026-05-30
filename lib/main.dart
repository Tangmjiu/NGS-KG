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
import 'screens/player_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/logger.dart';
import 'services/api_client.dart';
import 'theme/theme_assets.dart';
import 'providers/theme_provider.dart';
import 'widgets/support_me_dialog.dart';
import 'widgets/update_dialog.dart';
import 'services/update_checker.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'services/device_service.dart';
import 'services/music_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/cache_service.dart';
import 'providers/audio_settings_provider.dart';

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
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThemeImage(
              assetPath: ThemeAssets.codecrash,
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 12),
            const Text('渲染异常',
                style: TextStyle(color: Colors.white70, fontSize: 16)),
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
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
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
            // NavigationBar 的实际高度 = kBottomNavigationBarHeight + 底部安全区
            // 不加 padding 的话 mini 播放栏会叠加到 NavigationBar 上
            final bottomNavOffset =
                kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom;
            return Stack(
              children: [
                child ?? const SizedBox.shrink(),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: bottomNavOffset,
                  child: _PlayerBarBottom(),
                ),
                const _ContinuePlayOverlay(),
                const _SupportPopupHandler(),
                const _UpdateCheckHandler(),
              ],
            );
            },
          );
        },
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
      final devInfo = body['dev_info'] as Map<String, dynamic>?;
      final wording = devInfo?['wording'] as String? ?? '其他设备';
      // 优先用 curr_song，回退到 songs[0]
      Map<String, dynamic>? songInfo;
      final currSong = body['curr_song'] as Map?;
      if (currSong is Map) {
        songInfo = (currSong['info'] as Map<String, dynamic>?)
            ?? currSong.cast<String, dynamic>();
      }
      if (songInfo == null) {
        final songs = body['songs'] as List<dynamic>? ?? [];
        if (songs.isNotEmpty && songs[0] is Map<String, dynamic>) {
          songInfo = songs[0] as Map<String, dynamic>;
        }
      }
      if (songInfo != null && mounted) {
        final info = songInfo;
        final songName = (info['name'] as String?
            ?? info['songname'] as String? ?? '未知歌曲')
            .replaceAll(RegExp(r'\.mp3$', caseSensitive: false), '');
        final singer = info['singername'] as String?;
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
                  title: const Text('继续播放'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('检测到在 $wording'),
                      const SizedBox(height: 8),
                      Text(songName,
                          style: Theme.of(context).textTheme.titleMedium),
                      if (singer != null) Text(singer, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消')),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        final hash = info['hash'] as String?;
                        final songId = (info['mixsongid'] as num?)?.toInt()
                            ?? (info['id'] as num?)?.toInt() ?? 0;
                        final song = Song(
                          id: songId,
                          name: songName,
                          artists: singer != null ? [singer] : [],
                          albumCoverUrl: (info['cover'] as String?)
                              ?.replaceAll('{size}', '480'),
                          duration: (info['timelen'] as num?)?.toInt() ?? 0,
                          hash: hash,
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

/// 自动弹出支持作者弹窗（安装后一段时间内，每次开软件弹一次）
class _SupportPopupHandler extends StatefulWidget {
  const _SupportPopupHandler();
  @override
  State<_SupportPopupHandler> createState() => _SupportPopupHandlerState();
}

class _SupportPopupHandlerState extends State<_SupportPopupHandler> {
  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_shown) {
      _shown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
    }
  }

  Future<void> _maybeShow() async {
    if (!mounted) return;
    final tp = context.read<ThemeProvider>();
    if (!tp.shouldShowSupportPopup) return;

    final dismissed = await showSupportMeDialog(context, autoPopup: true);
    if (dismissed && mounted) {
      tp.dismissSupportPopup();
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// 启动时检查 GitHub Release 更新
class _UpdateCheckHandler extends StatefulWidget {
  const _UpdateCheckHandler();
  @override
  State<_UpdateCheckHandler> createState() => _UpdateCheckHandlerState();
}

class _UpdateCheckHandlerState extends State<_UpdateCheckHandler> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checked) {
      _checked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  Future<void> _check() async {
    if (!mounted) return;
    final release = await UpdateChecker.check();
    if (release != null && mounted) {
      showUpdateDialog(context, release);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

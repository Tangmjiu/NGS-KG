import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/player_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/liked_songs_provider.dart';
import 'routes/app_routes.dart';
import 'utils/theme.dart';
import 'screens/player_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/logger.dart';
import 'services/api_client.dart';
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
      Log.e('FLUTTER', details.exceptionAsString(), details.exception, details.stack);
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
    // Use debugPrint instead of Log to avoid side effects during build phase
    debugPrint('RENDER_ERROR: ${details.exceptionAsString()}');
    return Container(
      color: const Color(0xFF1A1C19),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('渲染异常', style: TextStyle(color: Colors.white70, fontSize: 16)),
        ),
      ),
    );
  };

  runZonedGuarded(() {
    _initDevice();
    _initNotifications();
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
        ],
        child: const NGSKGApp(),
      ),
    );
  }, (error, stack) {
    Log.e('ZONE', 'Unhandled async error', error, stack);
  });
}

Future<void> _initDevice() async {
  try {
    final dfid = await MusicService().registerDevice();
    if (dfid.isNotEmpty) ApiClient.setDfid(dfid);
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
            const Positioned(
              left: 0, right: 0, bottom: 0,
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
        if (song == null || player.isPlayerScreenVisible) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            SizedBox(
              height: 2,
              child: ClipRRect(
                child: LinearProgressIndicator(
                  value: player.progress.isFinite ? player.progress : 0.0,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: cs.primary,
                  minHeight: 2,
                ),
              ),
            ),
            // 主体
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: 8, right: 12, top: 6,
                bottom: MediaQuery.of(context).padding.bottom + 4,
              ),
              child: GestureDetector(
                onTap: () {
                  player.setPlayerScreenVisible(true);
                  navKey.currentState
                      ?.push(MaterialPageRoute(builder: (_) => const PlayerScreen()))
                      .then((_) => player.setPlayerScreenVisible(false));
                },
                child: Row(
                  children: [
                    // 专辑封面
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 44, height: 44,
                        child: song.albumCoverUrl != null && song.albumCoverUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: song.albumCoverUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => _fallbackCover(cs),
                                errorWidget: (_, __, ___) => _fallbackCover(cs),
                              )
                            : _fallbackCover(cs),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 歌名 + 歌手
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(song.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    // 播放控制
                    if (player.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: SizedBox(width: 28, height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.5)),
                      )
                    else ...[
                      const SizedBox(width: 4),
                      _MiniBtn(
                        icon: Icons.skip_previous,
                        size: 22,
                        onTap: player.playPrevious,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            player.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: cs.onPrimary, size: 22,
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
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _fallbackCover(ColorScheme cs) => Container(
    width: 44, height: 44,
    color: cs.surfaceContainerHighest,
    child: Icon(Icons.music_note, size: 22, color: cs.onSurfaceVariant),
  );
}

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  const _MiniBtn({required this.icon, this.size = 22, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36, height: 36,
      child: IconButton(
        icon: Icon(icon, size: size),
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
    try {
      final info = await MusicService().getContinuePlayInfo();
      if (!mounted) return;
      final data = info['data'] as Map<String, dynamic>? ?? info;
      final songs = data['songs'] as List<dynamic>? ?? [];
      if (songs.isNotEmpty && songs[0] is Map<String, dynamic>) {
        final s = songs[0] as Map<String, dynamic>;
        if (!mounted) return;
        showDialog(context: context, builder: (_) => AlertDialog(
          title: const Text('继续播放'),
          content: Text('检测到在其他设备播放了\n${s['name'] ?? ''}，是否继续？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('继续')),
          ],
        ));
      }
    } catch (e, s) { Log.e('main', 'error', e, s); }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

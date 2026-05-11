import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/player_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/liked_songs_provider.dart';
import 'routes/app_routes.dart';
import 'utils/theme.dart';
import 'screens/player_screen.dart';
import 'screens/settings_screen.dart';
import 'services/api_client.dart';
import 'services/music_service.dart';
import 'services/notification_service.dart';
import 'services/cache_service.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

void main() {
  _initDevice();
  _initNotifications();
  CacheService.instance.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider(create: (_) => LikedSongsProvider()),
      ],
      child: const NGSKGApp(),
    ),
  );
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
            const _PlayerBarBottom(),
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
        if (player.currentSong == null || player.isPlayerScreenVisible) return const SizedBox.shrink();
        return Positioned(
          left: 0, right: 0, bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (player.progress > 0)
                LinearProgressIndicator(
                  value: player.progress,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  color: Theme.of(context).colorScheme.primary,
                  minHeight: 1.5,
                ),
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: EdgeInsets.only(
                  left: 12, right: 4, top: 6,
                  bottom: MediaQuery.of(context).padding.bottom + 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          player.setPlayerScreenVisible(true);
                          navKey.currentState?.push(
                            MaterialPageRoute(builder: (_) => const PlayerScreen()),
                          ).then((_) => player.setPlayerScreenVisible(false));
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(player.currentSong!.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                            Text(player.currentSong!.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                    if (player.isLoading)
                      const Padding(padding: EdgeInsets.all(8),
                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                    else ...[
                      IconButton(icon: const Icon(Icons.skip_previous, size: 20), onPressed: player.playPrevious,
                          padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36)),
                      IconButton(icon: Icon(player.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 28),
                          onPressed: player.togglePlayPause, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36)),
                      IconButton(icon: const Icon(Icons.skip_next, size: 20), onPressed: player.playNext,
                          padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
      if ((data['show'] as bool? ?? data['status'] == 1) && data['song'] != null) {
        final song = data['song'] as Map<String, dynamic>;
        if (!mounted) return;
        showDialog(context: context, builder: (_) => AlertDialog(
          title: const Text('继续播放'),
          content: Text('检测到在其他设备播放了\n${song['name'] ?? ''}，是否继续？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('继续')),
          ],
        ));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

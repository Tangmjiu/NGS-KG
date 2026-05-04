import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/player_provider.dart';
import 'providers/playlist_provider.dart';
import 'routes/app_routes.dart';
import 'utils/theme.dart';
import 'widgets/player_bar.dart';
import 'screens/player_screen.dart';
import 'services/api_client.dart';
import 'services/music_service.dart';

void main() {
  _initDevice();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
      ],
      child: const NGSKGApp(),
    ),
  );
}

Future<void> _initDevice() async {
  try {
    final dfid = await MusicService().registerDevice();
    if (dfid.isNotEmpty) {
      ApiClient.setDfid(dfid);
    }
  } catch (_) {}
}

class NGSKGApp extends StatelessWidget {
  const NGSKGApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NGS-KG+',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRoutes.generateRoute,
      builder: (context, child) {
        return Column(
          children: [
            Expanded(child: child ?? const SizedBox.shrink()),
            const _PlayerBarBottom(),
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
        if (player.currentSong == null) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (player.progress > 0)
              LinearProgressIndicator(
                value: player.progress,
                backgroundColor: Colors.grey[850],
                color: Theme.of(context).colorScheme.primary,
                minHeight: 1.5,
              ),
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: EdgeInsets.only(
                left: 12,
                right: 4,
                top: 6,
                bottom: MediaQuery.of(context).padding.bottom + 4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PlayerScreen()),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.currentSong!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            player.currentSong!.artistDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (player.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else ...[
                    IconButton(
                      icon: const Icon(Icons.skip_previous, size: 20),
                      onPressed: player.playPrevious,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36),
                    ),
                    IconButton(
                      icon: Icon(
                        player.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 28,
                      ),
                      onPressed: player.togglePlayPause,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next, size: 20),
                      onPressed: player.playNext,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
      final show = data['show'] as bool? ?? data['status'] == 1;
      if (show && data['song'] != null) {
        final song = data['song'] as Map<String, dynamic>;
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('继续播放'),
            content: Text(
                '检测到在其他设备播放了\n${song['name'] ?? ''}，是否继续？'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消')),
              FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('继续')),
            ],
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

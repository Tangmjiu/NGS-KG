import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/player_provider.dart';
import 'providers/playlist_provider.dart';
import 'routes/app_routes.dart';
import 'utils/theme.dart';
import 'widgets/player_bar.dart';
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
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const _GlobalPlayerBar(),
            const _ContinuePlayOverlay(),
          ],
        );
      },
    );
  }
}

class _GlobalPlayerBar extends StatelessWidget {
  const _GlobalPlayerBar();

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (_, player, __) {
        if (player.currentSong == null) {
          return const SizedBox.shrink();
        }
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: PlayerBar(),
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
            content: Text('检测到在其他设备播放了\n${song['name'] ?? ''}，是否继续？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              FilledButton(onPressed: () {
                Navigator.pop(context);
              }, child: const Text('继续')),
            ],
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

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

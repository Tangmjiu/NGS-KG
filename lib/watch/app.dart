// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wear_plus/wear_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/player_provider.dart';
import '../utils/navigation.dart';
import 'screens/home_screen.dart';
import 'screens/player_screen.dart';
import 'screens/search_screen.dart';
import 'screens/playlist_list_screen.dart';
import 'screens/rank_list_screen.dart';
import 'screens/local_music_screen.dart';
import 'screens/fm_screen.dart';
import 'utils/watch_motion.dart';
import 'widgets/mini_player.dart';
import 'theme/watch_theme.dart';
import 'theme/watch_theme_provider.dart';

/// NGS-KG+ Watch 根组件 — Wear OS 优化的圆屏界面
class NGSKGWearApp extends StatelessWidget {
  const NGSKGWearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WatchShape(
      builder: (context, shape, child) {
        return Consumer<WatchThemeProvider>(
          builder: (context, themeProvider, _) {
            return MaterialApp(
              navigatorKey: navKey,
              title: 'NGS-KG+ Watch',
              locale: const Locale('zh', 'CN'),
              debugShowCheckedModeBanner: false,
              darkTheme: buildWatchTheme(themeProvider.colorSeed),
              themeMode: ThemeMode.dark,
              home: const WatchHome(),
            );
          },
        );
      },
    );
  }
}

/// 主外壳：MiniPlayer + PageView（左右滑动切换页面）
class WatchHome extends StatefulWidget {
  const WatchHome({super.key});

  @override
  State<WatchHome> createState() => _WatchHomeState();
}

class _WatchHomeState extends State<WatchHome> {
  final _pageController = PageController();
  int _currentPage = 0;

  final List<Widget> _pages = const [
    WatchHomeScreen(),
    WatchSearchScreen(),
    WatchPlaylistListScreen(),
    WatchRankListScreen(),
    WatchLocalMusicScreen(),
    WatchFmScreen(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shape = WatchShape.of(context);
    final isRound = shape == WearShape.round;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && mounted) {
          if (_currentPage > 0) {
            _pageController.previousPage(
              duration: WatchMotion.durMedium2,
              curve: WatchMotion.curveStandard,
            );
          }
        }
      },
      child: Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: _pages,
          ),

          Positioned(
            top: isRound ? 22 : 4,
            left: 0,
            right: 0,
            child: _PageIndicator(
              count: _pages.length,
              current: _currentPage,
              isRound: isRound,
            ),
          ),

          if (_currentPage != 1 && _currentPage != 5)
            Positioned(
              bottom: isRound ? 16 : 4,
              left: isRound ? 70 : 8,
              right: isRound ? 70 : 8,
              child: Consumer<PlayerProvider>(
                builder: (context, player, _) {
                  if (player.currentSong == null) return const SizedBox.shrink();
                  return GestureDetector(
                    onTap: () {
                      WatchMotion.tap();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WatchPlayerScreen()),
                      );
                    },
                    child: const WatchMiniPlayer()
                        .animate()
                        .fadeIn(duration: WatchMotion.durMedium2, curve: WatchMotion.curveDecelerate)
                        .slideY(
                          begin: 0.3,
                          end: 0,
                          duration: WatchMotion.durMedium2,
                          curve: WatchMotion.curveEmphasized,
                        ),
                  );
                },
              ),
            ),
        ],
      ),
    ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int count;
  final int current;
  final bool isRound;

  const _PageIndicator({
    required this.count,
    required this.current,
    required this.isRound,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (i) {
          final isActive = i == current;
          return AnimatedContainer(
            duration: WatchMotion.durShort4,
            curve: WatchMotion.curveEmphasized,
            width: isActive ? 10 : 5,
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        }),
      ),
    );
  }
}

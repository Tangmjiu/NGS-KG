// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// NGS-KG+ Watch 根组件 — 四主视图横向导航、首次引导、全局息屏

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wear_plus/wear_plus.dart';
import 'package:wearable_rotary/wearable_rotary.dart';

import '../providers/player_provider.dart';
import '../utils/navigation.dart';
import 'screens/hubs.dart';
import 'screens/onboarding_screen.dart';
import 'screens/player_screen.dart';
import 'theme/watch_theme.dart';
import 'theme/watch_theme_provider.dart';
import 'utils/watch_layout.dart';
import 'utils/watch_motion.dart';
import 'widgets/mini_player.dart';
import 'widgets/watch_quick_panel.dart';
import 'widgets/watch_scaffold.dart';

/// NGS-KG+ Watch 根组件。
///
/// 信息架构：横向 PageView 四主视图（聆听 / 发现 / 音乐库 / 设备与我），
/// 无底部 Tab；首次启动先进入两页交互引导。
class NGSKGWearApp extends StatefulWidget {
  const NGSKGWearApp({super.key});

  @override
  State<NGSKGWearApp> createState() => _NGSKGWearAppState();
}

class _NGSKGWearAppState extends State<NGSKGWearApp> {
  /// null=加载中；true=已完成引导
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    WatchOnboardingScreen.isDone().then((done) {
      if (mounted) setState(() => _onboardingDone = done);
    });
  }

  @override
  Widget build(BuildContext context) {
    return WatchShape(
      builder: (context, shape, child) {
        return Consumer<WatchThemeProvider>(
          builder: (context, themeProvider, _) {
            final done = _onboardingDone;
            return MaterialApp(
              navigatorKey: navKey,
              title: 'NGS-KG+ Watch',
              locale: const Locale('zh', 'CN'),
              debugShowCheckedModeBanner: false,
              darkTheme: buildWatchTheme(themeProvider.colorSeed),
              themeMode: ThemeMode.dark,
              home: done == null
                  ? const Scaffold(backgroundColor: Colors.black)
                  : done
                  ? const WatchHome()
                  : WatchOnboardingScreen(
                      onDone: () => setState(() => _onboardingDone = true),
                    ),
            );
          },
        );
      },
    );
  }
}

/// 主外壳：TimeText + 四主视图 + 弧形页指示 + MiniPlayer + 快捷面板 + 息屏。
class WatchHome extends StatefulWidget {
  const WatchHome({super.key});

  @override
  State<WatchHome> createState() => _WatchHomeState();
}

class _WatchHomeState extends State<WatchHome> {
  final _pageController = PageController();
  int _currentPage = 0;
  final _hubScroll = List.generate(4, (_) => ScrollController());
  StreamSubscription<RotaryEvent>? _rotarySub;

  bool _ambient = false;

  static const _pages = [
    ListenHubPage(),
    DiscoverHubPage(),
    LibraryHubPage(),
    MeHubPage(),
  ];

  @override
  void initState() {
    super.initState();
    _rotarySub = rotaryEvents.listen((event) {
      if (!mounted || _ambient || ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final scroll = _hubScroll[_currentPage];
      if (!scroll.hasClients || !scroll.position.hasContentDimensions) return;
      final position = scroll.position;
      final step = (event.magnitude?.abs() ?? 28.0).clamp(6.0, 60.0);
      final delta = event.direction == RotaryDirection.clockwise ? step : -step;
      scroll.jumpTo(
        (position.pixels + delta).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  @override
  void dispose() {
    _rotarySub?.cancel();
    _pageController.dispose();
    for (final scroll in _hubScroll) {
      scroll.dispose();
    }
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: WatchMotion.durMedium2,
      curve: WatchMotion.curveStandard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);

    return AmbientMode(
      builder: (context, mode, child) {
        _ambient = mode == WearMode.ambient;
        if (_ambient) return const WatchChronoFace();
        return _buildActive(context, layout);
      },
    );
  }

  Widget _buildActive(BuildContext context, WatchLayout layout) {
    return PopScope(
      // 第一页允许系统返回（退出应用），其余页先回到聆听
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && mounted && _currentPage > 0) _goToPage(0);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          // 底缘上滑 → 快捷面板（hub 页面无纵向滚动，手势可直达）
          // 仅处理快速上滑（velocity 阈值高），不拦截 TextField 的普通触摸
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -800) {
              WatchQuickPanel.show(context);
            }
          },
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    PrimaryScrollController(
                      controller: _hubScroll[i],
                      child: _pages[i],
                    ),
                ],
              ),

              // ── 顶部时间 ──
              Positioned(
                top: layout.isRound ? 6 : 4,
                left: 0,
                right: 0,
                child: const WatchTimeText(),
              ),

              // ── 右缘弧形页面指示 ──
              Positioned(
                right: layout.isRound ? 8 : 4,
                top: 0,
                bottom: 0,
                child: _EdgePageIndicator(
                  count: _pages.length,
                  current: _currentPage,
                ),
              ),

              // ── 底部 MiniPlayer（聆听页自身即播放速览，不重复显示）──
              if (_currentPage != 0)
                Positioned(
                  bottom: layout.isRound ? 18 : 8,
                  left: layout.isRound ? layout.diameter * 0.16 : 10,
                  right: layout.isRound ? layout.diameter * 0.16 : 10,
                  child: Consumer<PlayerProvider>(
                    builder: (context, player, _) {
                      if (player.currentSong == null) {
                        return const SizedBox.shrink();
                      }
                      return GestureDetector(
                        onTap: () {
                          WatchMotion.tap();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WatchPlayerScreen(),
                            ),
                          );
                        },
                        child: const WatchMiniPlayer(),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  全局息屏（Ambient）：纯黑底、单色白、细进度弧、无动画
// ═══════════════════════════════════════════════════════

/// 右缘纵向页面指示（Wear M3 风格：当前页为长胶囊，其余为圆点）。
class _EdgePageIndicator extends StatelessWidget {
  final int count;
  final int current;

  const _EdgePageIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (i) {
          final isActive = i == current;
          return AnimatedContainer(
            duration: WatchMotion.durShort4,
            curve: WatchMotion.curveEmphasized,
            width: 4,
            height: isActive ? 14 : 4,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: isActive
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}

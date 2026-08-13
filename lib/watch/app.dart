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
  StreamSubscription<RotaryEvent>? _rotarySub;

  /// 表冠翻页节流：避免一次旋拧连跳多页
  DateTime _lastRotaryPageTurn = DateTime.fromMillisecondsSinceEpoch(0);

  static const _pages = [
    ListenHubPage(),
    DiscoverHubPage(),
    LibraryHubPage(),
    MeHubPage(),
  ];

  @override
  void initState() {
    super.initState();
    // 旋转表冠：在主视图层左右翻页（仅当外壳为当前路由，
    // 避免被推到上层的滚动页面重复消费）
    _rotarySub = rotaryEvents.listen((event) {
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;
      final now = DateTime.now();
      if (now.difference(_lastRotaryPageTurn).inMilliseconds < 280) return;
      _lastRotaryPageTurn = now;
      if (event.direction == RotaryDirection.clockwise) {
        _goToPage((_currentPage + 1).clamp(0, _pages.length - 1));
      } else {
        _goToPage((_currentPage - 1).clamp(0, _pages.length - 1));
      }
    });
  }

  @override
  void dispose() {
    _rotarySub?.cancel();
    _pageController.dispose();
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
        if (mode == WearMode.ambient) return const _AmbientHomeView();
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
                children: _pages,
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

class _AmbientHomeView extends StatefulWidget {
  const _AmbientHomeView();

  @override
  State<_AmbientHomeView> createState() => _AmbientHomeViewState();
}

class _AmbientHomeViewState extends State<_AmbientHomeView> {
  Timer? _minuteTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  void _scheduleTick() {
    final now = DateTime.now();
    _minuteTimer = Timer(
      Duration(seconds: 60 - now.second, milliseconds: -now.millisecond),
      () {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
        _scheduleTick();
      },
    );
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    final timeStr =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<PlayerProvider>(
        builder: (context, player, _) {
          final song = player.currentSong;
          return Center(
            child: Padding(
              padding: EdgeInsets.all(layout.diameter * 0.16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 细进度线
                  ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: LinearProgressIndicator(
                      value: player.progress.clamp(0.0, 1.0),
                      minHeight: 2,
                      color: Colors.white38,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (song != null) ...[
                    Text(
                      song.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Icon(
                      player.isPlaying
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: Colors.white54,
                      size: 16,
                    ),
                  ] else
                    const Icon(Icons.music_note_rounded,
                        color: Colors.white38, size: 18),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

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

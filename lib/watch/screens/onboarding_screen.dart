// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 首次启动引导 — 第 1 页：欢迎 + 旋转表冠；第 2 页：核心手势教学

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/watch_layout.dart';
import '../utils/watch_motion.dart';

/// 首次启动引导（两页，左右滑动/点击切换）。
///
/// 完成后写入 `watch_onboarding_done = true`，之后不再出现。
class WatchOnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const WatchOnboardingScreen({super.key, required this.onDone});

  /// SharedPreferences 键。
  static const String kDoneKey = 'watch_onboarding_done';

  /// 读取是否已完成引导。
  static Future<bool> isDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(kDoneKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _finish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kDoneKey, true);
    } catch (_) {}
    onDone();
  }

  @override
  State<WatchOnboardingScreen> createState() => _WatchOnboardingScreenState();
}

class _WatchOnboardingScreenState extends State<WatchOnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // 页面内容（占满剩余空间）
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                _CrownPage(layout: layout),
                _GesturePage(layout: layout),
              ],
            ),
          ),
          // 底部固定区：页指示 + 操作按钮（不被圆边裁切）
          Padding(
            padding: EdgeInsets.only(
              bottom: layout.bottomInset * 0.5 + 6,
              top: 4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 页指示：双圆点
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(2, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: WatchMotion.durShort4,
                      curve: WatchMotion.curveEmphasized,
                      width: active ? 14 : 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: active
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                // 操作按钮：第 1 页「下一步」，第 2 页「开始使用」
                Center(
                  child: FilledButton(
                    onPressed: () {
                      WatchMotion.confirm();
                      if (_page == 0) {
                        _pageController.nextPage(
                          duration: WatchMotion.durMedium2,
                          curve: WatchMotion.curveStandard,
                        );
                      } else {
                        widget._finish();
                      }
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(96, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: Text(_page == 0 ? '下一步' : '开始使用'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 第 1 页：欢迎 + 旋转表冠功能介绍（旋转动画示意）。
class _CrownPage extends StatefulWidget {
  final WatchLayout layout;
  const _CrownPage({required this.layout});

  @override
  State<_CrownPage> createState() => _CrownPageState();
}

class _CrownPageState extends State<_CrownPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _crown = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _crown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ringSize = layout.diameter * 0.30;

    // 可滚动兜底：小屏（192dp）内容超高时不溢出
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: layout.contentHorizontal),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: layout.topInset * 0.5),
                  Text(
                    'NGS-KG+ Watch',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('旋转表冠 随心掌控', style: theme.textTheme.bodySmall),
                  SizedBox(height: layout.diameter * 0.06),
                  // 表冠动画：外圈滚动刻度
                  AnimatedBuilder(
                    animation: _crown,
                    builder: (context, _) {
                      return SizedBox(
                        width: ringSize,
                        height: ringSize,
                        child: CustomPaint(
                          painter: _CrownPainter(
                            phase: _crown.value,
                            color: cs.primary,
                            track: cs.surfaceContainerHighest,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.watch_rounded,
                              size: ringSize * 0.34,
                              color: cs.onSurface.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: layout.diameter * 0.06),
                  Text(
                    '转动表冠滚动列表\n播放页旋转调音量',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // 底部避让「下一步」按钮
                  SizedBox(height: layout.diameter * 0.06),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CrownPainter extends CustomPainter {
  final double phase;
  final Color color;
  final Color track;

  const _CrownPainter(
      {required this.phase, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 3;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, trackPaint);

    // 旋转的高亮弧段，示意表冠旋转
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final start = phase * math.pi * 2 - math.pi / 2;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start,
        math.pi * 0.6, false, paint);
  }

  @override
  bool shouldRepaint(_CrownPainter old) => old.phase != phase;
}

/// 第 2 页：核心手势教学。
class _GesturePage extends StatelessWidget {
  final WatchLayout layout;
  const _GesturePage({required this.layout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final gestures = [
      (Icons.swipe_rounded, '左右滑动', '切换主视图 / 播放页切歌'),
      (Icons.swipe_up_rounded, '底缘上滑', '调出快捷操作面板'),
      (Icons.touch_app_rounded, '双击屏幕', '播放 / 暂停'),
      (Icons.smart_button_rounded, '点击分区', '所有功能均可点按完成'),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: layout.contentHorizontal),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            SizedBox(height: layout.topInset * 0.5),
            Text(
              '核心手势',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            SizedBox(height: 8 * layout.scale),
            for (final (icon, title, desc) in gestures)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 3 * layout.scale),
                child: Row(
                  children: [
                    Container(
                      width: 30 * layout.scale,
                      height: 30 * layout.scale,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon,
                          size: 15 * layout.scale, color: cs.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            desc,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // 底部避让「开始使用」按钮
            SizedBox(height: layout.diameter * 0.04),
          ],
        ),
      ),
    );
  }
}

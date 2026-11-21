// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/watch_motion.dart';
import 'login_screen.dart';

class WatchOnboardingScreen extends StatefulWidget {
  const WatchOnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;
  static const String kDoneKey = 'watch_onboarding_done';

  static Future<bool> isDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(kDoneKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  State<WatchOnboardingScreen> createState() => _WatchOnboardingScreenState();
}

class _WatchOnboardingScreenState extends State<WatchOnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  bool _finishing = false;

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    WatchMotion.confirm();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(WatchOnboardingScreen.kDoneKey, true);
    } catch (_) {
      // 偏好设置不可用时仍允许进入主页。
    }
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pages,
      itemCount: 2,
      onPageChanged: (index) => setState(() => _page = index),
      itemBuilder: (context, index) {
        final crown = index == 0;
        final colors = Theme.of(context).colorScheme;
        return WatchFlowPage(
          title: crown ? '转动表冠' : '滑动和轻点',
          center: true,
          active: _page == index,
          swipeBack: false,
          symbol: Semantics(
            label: '第 ${index + 1} 页，共 2 页',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: crown ? 52 : 96,
                  height: crown ? 52 : 38,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Icon(
                    crown ? Icons.gesture_rounded : Icons.swipe_rounded,
                    size: 29,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                if (crown)
                  CustomPaint(
                    size: const Size(16, 7),
                    painter: _HintPointer(colors.primaryContainer),
                  ),
              ],
            ),
          ),
          children: [
            Text(
              crown ? '转动表冠浏览列表，在播放页调节音量。' : '首页左右滑动翻页，向上快滑打开快捷面板。双击播放页可暂停或继续。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _finishing
                  ? null
                  : () {
                      if (_page != index) return;
                      if (crown) {
                        WatchMotion.tap();
                        if (MediaQuery.disableAnimationsOf(context)) {
                          _pages.jumpToPage(1);
                        } else {
                          _pages.nextPage(
                            duration: WatchMotion.durMedium2,
                            curve: WatchMotion.curveStandard,
                          );
                        }
                      } else {
                        _finish();
                      }
                    },
              child: Text(crown ? '下一步' : '开始使用'),
            ),
          ],
        );
      },
    );
  }
}

class _HintPointer extends CustomPainter {
  const _HintPointer(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final triangle = Path()
      ..moveTo(0, -2)
      ..lineTo(size.width, -2)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(triangle, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_HintPointer previous) => color != previous.color;
}

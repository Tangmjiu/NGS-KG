// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';
import '../theme/theme_assets.dart';
import 'expressive_shapes.dart';

/// 应用内启动页（借鉴 Rhythm SplashScreen 动效）
///
/// - 背景：主题色 Expressive 形状漂浮（呼吸 + 漂移 + 摆动）
/// - 内容：logo 弹性入场 + 呼吸脉冲
/// - 底部：状态文字 + 三点错峰加载指示
///
/// 纯展示组件，不依赖播放状态；退出动画由外层 [SplashGate] 的
/// AnimatedSwitcher（缩放 + 淡出）完成。
class SplashScreen extends StatefulWidget {
  /// 底部加载状态文字
  final String statusText;

  const SplashScreen({super.key, this.statusText = '正在加载…'});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _logoPulse;
  late final AnimationController _dots;

  late final Animation<double> _contentOpacity;
  late final Animation<double> _contentScale;
  late final Animation<double> _logoScale;
  late final Animation<double> _dot1;
  late final Animation<double> _dot2;
  late final Animation<double> _dot3;

  @override
  void initState() {
    super.initState();

    // 入场：内容淡入 + 弹性放大（0.82 → 1.0）
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _contentOpacity = CurvedAnimation(
      parent: _entrance,
      curve: AppMotion.emphasizedDecelerate,
    );
    _contentScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _entrance, curve: Curves.elasticOut),
    );

    // logo 呼吸脉冲（2s 往返）
    _logoPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _logoScale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _logoPulse, curve: Curves.easeInOut),
    );

    // 三点加载：错峰闪烁
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _dot1 = _phaseDot(_dots, 0.00);
    _dot2 = _phaseDot(_dots, 0.33);
    _dot3 = _phaseDot(_dots, 0.66);
  }

  /// 在共享父动画上取一段错峰区间（0.35 → 1.0 不透明度）
  Animation<double> _phaseDot(Animation<double> parent, double begin) {
    final end = (begin + 0.33).clamp(0.0, 1.0);
    return Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(
        parent: parent,
        curve: Interval(begin, end, curve: AppMotion.emphasizedDecelerate),
      ),
    );
  }

  @override
  void dispose() {
    _entrance.dispose();
    _logoPulse.dispose();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Material(
      color: scheme.surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── 背景漂浮形状（随入场淡入） ──
          FadeTransition(
            opacity: _contentOpacity,
            child: const ThemedFloatingShapes(seed: 7, count: 8),
          ),

          // ── 中央 logo + 标题 ──
          Center(
            child: FadeTransition(
              opacity: _contentOpacity,
              child: ScaleTransition(
                scale: _contentScale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _logoScale,
                      child: _buildLogo(scheme),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'NGS-KG+',
                      style: textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '你的音乐，你的节奏',
                      style: textTheme.titleSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── 底部加载状态 ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 64 + bottomInset,
            child: FadeTransition(
              opacity: _contentOpacity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.statusText,
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDot(scheme, _dot1),
                      const SizedBox(width: 8),
                      _buildDot(scheme, _dot2),
                      const SizedBox(width: 8),
                      _buildDot(scheme, _dot3),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(ColorScheme scheme) {
    return Container(
      width: 92,
      height: 92,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // Squircle 圆角（28dp ≈ Expressive 专辑封面圆角）
        borderRadius: BorderRadius.circular(28),
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: ThemeImage(
        assetPath: ThemeAssets.icon,
        width: 92,
        height: 92,
      ),
    );
  }

  Widget _buildDot(ColorScheme scheme, Animation<double> opacity) {
    return FadeTransition(
      opacity: opacity,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// 启动浮层门卫：等待初始化信号 + 最短展示时长后，缩放淡出移除
///
/// 作为 MaterialApp.builder Stack 的最顶层组件使用：
/// - [ready]：初始化完成信号（默认 AuthProvider.ready）
/// - [minDisplay]：保证动效完整展示的最短时长
///
/// 不阻塞底层路由/播放初始化，完成后自行消失，可逆可配置。
class SplashGate extends StatefulWidget {
  /// 初始化完成信号（null 表示只按最短时长展示）
  final Future<void> Function()? ready;

  /// 最短展示时长（确保入场动效可感知）
  final Duration minDisplay;

  const SplashGate({
    super.key,
    this.ready,
    this.minDisplay = const Duration(milliseconds: 1500),
  });

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _done = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _start();
    }
  }

  Future<void> _start() async {
    try {
      final Future<void> ready = widget.ready != null
          ? widget.ready!()
          : context.read<AuthProvider>().ready;
      await Future.wait([
        ready,
        Future<void>.delayed(widget.minDisplay),
      ]);
    } catch (_) {
      // ready 异常不阻塞，按最短时长继续
    }
    if (!mounted) return;
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.dMedium4,
      switchInCurve: AppMotion.emphasizedDecelerate,
      switchOutCurve: AppMotion.emphasizedAccelerate,
      transitionBuilder: (child, animation) {
        // 同一 Tween 双向适配：入场 0.92→1.0 放大，出场 1.0→0.92 缩小
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 0.92).animate(animation),
            child: child,
          ),
        );
      },
      child: _done
          ? const SizedBox.shrink(key: ValueKey('splash-done'))
          : const SplashScreen(key: ValueKey('splash')),
    );
  }
}

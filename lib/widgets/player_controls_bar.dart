// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/app_icons.dart';
import '../utils/haptics.dart';
import '../utils/theme.dart';

/// Three-button player controls: previous, play/pause, next.
/// Mode toggle and playlist button have been moved to the bottom icon bar.
///
/// Rhythm 风格动效（对标 AnimatedPlaybackControls）：
///   - 权重弹跳：点击的按钮膨胀至 1.1，其余两个压缩至 0.65，220ms 后弹回
///   - 播放/暂停图标切换：弹性缩放（easeOutBack overshoot）+ 轻微旋转 + 淡入
///   - 按下时主按钮整体微缩（按压反馈）
///   - 切换/切歌附带触感反馈
class PlayerControlsBar extends StatefulWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const PlayerControlsBar({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  State<PlayerControlsBar> createState() => _PlayerControlsBarState();
}

class _PlayerControlsBarState extends State<PlayerControlsBar> {
  /// 当前被"权重弹跳"选中的按钮索引（-1 = 无）
  int _weightIndex = -1;
  Timer? _weightTimer;

  @override
  void dispose() {
    _weightTimer?.cancel();
    super.dispose();
  }

  void _press(int index) {
    setState(() => _weightIndex = index);
    _weightTimer?.cancel();
    _weightTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _weightIndex = -1);
    });
  }

  /// Rhythm 权重映射：自身 1.1 / 其余 0.65 / 无选中 1.0
  double _weightFor(int index) {
    if (_weightIndex == -1) return 1.0;
    return _weightIndex == index ? 1.1 : 0.65;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // -- Previous --
        _WeightedButton(
          scale: _weightFor(0),
          child: _SkipButton(
            icon: AppIcons.skipPrevious,
            tooltip: '上一首',
            onTap: () {
              _press(0);
              unawaited(haptic(HapticKind.light));
              widget.onPrevious();
            },
          ),
        ),

        const SizedBox(width: 8),

        // -- Play / Pause --
        _WeightedButton(
          scale: _weightFor(1),
          child: _PlayPauseButton(
            isPlaying: widget.isPlaying,
            isLoading: widget.isLoading,
            onTap: () {
              _press(1);
              unawaited(haptic(HapticKind.medium));
              widget.onPlayPause();
            },
          ),
        ),

        const SizedBox(width: 8),

        // -- Next --
        _WeightedButton(
          scale: _weightFor(2),
          child: _SkipButton(
            icon: AppIcons.skipNext,
            tooltip: '下一首',
            onTap: () {
              _press(2);
              unawaited(haptic(HapticKind.light));
              widget.onNext();
            },
          ),
        ),
      ],
    );
  }
}

/// 权重弹跳动画层：AnimatedScale + easeOutBack 轻微 overshoot
class _WeightedButton extends StatelessWidget {
  final double scale;
  final Widget child;

  const _WeightedButton({required this.scale, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: child,
    );
  }
}

/// 上一首/下一首按钮：M3 标准 48dp 触控目标 + Material Symbols 图标
class _SkipButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _SkipButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return M3PressScale(
      scaleDown: 0.88,
      child: IconButton(
        icon: AppIcon(
          icon,
          size: 36,
          color: Colors.white,
          weight: 500,
          opticalSize: 40,
        ),
        tooltip: tooltip,
        onPressed: onTap,
        splashRadius: 24,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
      ),
    );
  }
}

/// 播放/暂停主按钮：白色圆盘（布局不变），图标弹性切换
class _PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onTap;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton>
    with SingleTickerProviderStateMixin {
  /// 按压缩放控制器：按下 1.0 → 0.92，松手 easeOutBack 弹回（轻微 overshoot）
  late final AnimationController _pressController;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: AppMotion.dShort3,
      reverseDuration: AppMotion.dShort4,
      value: 1.0,
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: AppMotion.emphasized),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) => _pressController.reverse(),
      onTapCancel: () => _pressController.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _pressScale,
        child: Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: _buildChild(),
        ),
      ),
    );
  }

  Widget _buildChild() {
    if (widget.isLoading) {
      return const SizedBox(
        key: ValueKey('loading'),
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Colors.black54,
        ),
      );
    }

    // 弹性切换：easeOutBack 让图标从 0.55 放大到 ~1.1 再弹回 1.0，
    // 叠加 45° 回旋与淡入，形成 Rhythm 式的"鼓点感"切换。
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: AppMotion.emphasizedAccelerate,
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.55, end: 1.0).animate(animation),
          child: RotationTransition(
            turns: Tween<double>(begin: -0.125, end: 0.0).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      child: AppIcon(
        widget.isPlaying ? AppIcons.pause : AppIcons.play,
        key: ValueKey<bool>(widget.isPlaying),
        size: 36,
        color: Colors.black87,
        weight: 700,
        opticalSize: 40,
      ),
    );
  }
}

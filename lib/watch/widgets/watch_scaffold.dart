// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 手表屏幕骨架 — TimeText、右滑返回、边缘滚动指示

import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/watch_layout.dart';

/// 手表屏幕骨架（Wear M3 风格）。
///
/// - 黑底 AMOLED
/// - 顶部 [WatchTimeText]（可关闭）
/// - [swipeBack] 开启后右滑返回（Wear 惯例），带跟手位移
/// - [scrollController] 传入后在右缘显示滚动位置指示
class WatchScaffold extends StatelessWidget {
  final Widget body;

  /// 是否显示顶部时间
  final bool showTime;

  /// 是否启用右滑返回手势
  final bool swipeBack;

  /// 关联的滚动控制器（显示边缘滚动位置指示）
  final ScrollController? scrollController;

  const WatchScaffold({
    super.key,
    required this.body,
    this.showTime = true,
    this.swipeBack = true,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    Widget content = body;

    if (swipeBack) content = _SwipeBackWrapper(child: content);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: showTime ? layout.topInset : 0),
            child: content,
          ),
          if (showTime)
            Positioned(
              top: layout.isRound ? 6 : 4,
              left: 0,
              right: 0,
              child: const WatchTimeText(),
            ),
          if (scrollController != null)
            _EdgeScrollIndicator(
              controller: scrollController!,
              isRound: layout.isRound,
            ),
        ],
      ),
    );
  }
}

/// 顶部时间（Wear M3 TimeText 的 Flutter 版），每分钟自更新。
class WatchTimeText extends StatefulWidget {
  const WatchTimeText({super.key});

  @override
  State<WatchTimeText> createState() => _WatchTimeTextState();
}

class _WatchTimeTextState extends State<WatchTimeText> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  void _scheduleTick() {
    // 对齐到下一分钟边界，减少漂移
    final now = DateTime.now();
    final delay =
        Duration(seconds: 60 - now.second, milliseconds: -now.millisecond);
    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _scheduleTick();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    return Center(
      child: Text(
        '$h:$m',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// 右滑返回：跟手平移，超过阈值或快速甩动时返回上一页。
class _SwipeBackWrapper extends StatefulWidget {
  final Widget child;
  const _SwipeBackWrapper({required this.child});

  @override
  State<_SwipeBackWrapper> createState() => _SwipeBackWrapperState();
}

class _SwipeBackWrapperState extends State<_SwipeBackWrapper>
    with TickerProviderStateMixin {
  double _drag = 0;
  AnimationController? _resetController;

  @override
  void dispose() {
    _resetController?.dispose();
    super.dispose();
  }

  void _animateBack() {
    _resetController?.dispose();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _resetController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _resetController!.dispose();
        _resetController = null;
      }
    });
    final animation = Tween(begin: _drag, end: 0.0).animate(
      CurvedAnimation(parent: _resetController!, curve: Curves.easeOutCubic),
    );
    animation.addListener(() {
      if (mounted) setState(() => _drag = animation.value);
    });
    _resetController!.forward();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        // 只响应向右（返回方向）的拖动
        final next = _drag + details.delta.dx;
        if (next > 0) setState(() => _drag = next);
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (_drag > width * 0.35 || velocity > 700) {
          Navigator.of(context).maybePop();
        } else {
          _animateBack();
        }
      },
      onHorizontalDragCancel: _animateBack,
      child: Transform.translate(
        offset: Offset(_drag, 0),
        child: Opacity(
          opacity: (1 - _drag / width * 0.4).clamp(0.6, 1.0),
          child: widget.child,
        ),
      ),
    );
  }
}

/// 右缘滚动位置指示（Wear M3 PositionIndicator 简化版）。
class _EdgeScrollIndicator extends StatelessWidget {
  final ScrollController controller;
  final bool isRound;

  const _EdgeScrollIndicator({required this.controller, this.isRound = true});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: isRound ? 3 : 2,
      top: 0,
      bottom: 0,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (!controller.hasClients ||
              !controller.position.hasContentDimensions) {
            return const SizedBox.shrink();
          }
          final max = controller.position.maxScrollExtent;
          if (max <= 0) return const SizedBox.shrink();
          final fraction = (controller.offset / max).clamp(0.0, 1.0);
          return LayoutBuilder(
            builder: (context, constraints) {
              const thumbHeight = 28.0;
              final travel = constraints.maxHeight - thumbHeight;
              return Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: travel * fraction),
                  child: Container(
                    width: 3,
                    height: thumbHeight,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

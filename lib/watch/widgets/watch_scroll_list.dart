// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 手表通用滚动列表 — 表冠滚动、圆屏曲面衰减、精确自动定位

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wearable_rotary/wearable_rotary.dart';

import '../utils/watch_layout.dart';

/// 手表通用可滚动列表（Wear M3 风格）。
///
/// - 表冠/旋转表圈滚动（[RotaryScrollController]，外部可传入自己的控制器）
/// - [itemExtent] 固定行高：自动滚动定位精确（同时启用圆屏曲面衰减）
/// - [autoScrollTo] 变化时平滑滚动到目标行（用户手动滚动后 3 秒内暂停同步）
/// - 圆屏：靠近上下边缘的条目自动缩放/淡出（曲面列表观感）
class WatchScrollList extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ScrollController? controller;

  /// 固定行高。传入后启用精确滚动定位与曲面衰减。
  final double? itemExtent;

  /// 目标行索引，变化时自动滚动到该行。
  final int? autoScrollTo;

  /// [autoScrollTo] 的视口对齐（0 顶部 / 0.5 居中）。
  final double autoScrollAlignment;

  /// 底部额外留白（避让 MiniPlayer 等）。
  final double bottomPadding;

  /// 顶部额外留白。
  final double topPadding;

  const WatchScrollList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.itemExtent,
    this.autoScrollTo,
    this.autoScrollAlignment = 0.35,
    this.bottomPadding = 56.0,
    this.topPadding = 0.0,
  });

  @override
  State<WatchScrollList> createState() => _WatchScrollListState();
}

class _WatchScrollListState extends State<WatchScrollList> {
  late final ScrollController _controller;
  bool _isUserScrolling = false;
  Timer? _userScrollResetTimer;

  ScrollController get controller => _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? RotaryScrollController();
  }

  @override
  void didUpdateWidget(WatchScrollList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoScrollTo != null &&
        widget.autoScrollTo != oldWidget.autoScrollTo &&
        !_isUserScrolling &&
        _controller.hasClients) {
      _scrollToIndex(widget.autoScrollTo!);
    }
  }

  @override
  void dispose() {
    _userScrollResetTimer?.cancel();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onUserScroll() {
    _isUserScrolling = true;
    _userScrollResetTimer?.cancel();
    _userScrollResetTimer = Timer(const Duration(seconds: 3), () {
      _isUserScrolling = false;
    });
  }

  void _scrollToIndex(int index) {
    if (!_controller.hasClients) return;
    final extent = widget.itemExtent ?? 52.0;
    final viewport = _controller.position.viewportDimension;
    final target = index * extent +
        widget.topPadding -
        viewport * widget.autoScrollAlignment;
    _controller.animateTo(
      target.clamp(0.0, _controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    final curve = layout.curveStrength;
    final extent = widget.itemExtent;

    return NotificationListener<ScrollNotification>(
      onNotification: (notif) {
        if (notif is UserScrollNotification) _onUserScroll();
        return false;
      },
      child: ListView.builder(
        controller: _controller,
        itemExtent: extent,
        padding: EdgeInsets.fromLTRB(
          layout.listHorizontal,
          widget.topPadding,
          layout.listHorizontal,
          widget.bottomPadding,
        ),
        itemCount: widget.itemCount,
        // 固定行高 + 圆屏时启用曲面衰减包装
        itemBuilder: (curve > 0 && extent != null)
            ? (context, index) => _CurvedEdgeItem(
                  index: index,
                  extent: extent,
                  controller: _controller,
                  strength: curve,
                  child: widget.itemBuilder(context, index),
                )
            : widget.itemBuilder,
      ),
    );
  }
}

/// 圆屏曲面列表条目：靠近视口边缘时按距离平方衰减缩放与不透明度。
class _CurvedEdgeItem extends StatelessWidget {
  final int index;
  final double extent;
  final ScrollController controller;
  final double strength;
  final Widget child;

  const _CurvedEdgeItem({
    required this.index,
    required this.extent,
    required this.controller,
    required this.strength,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        var scale = 1.0;
        var opacity = 1.0;
        if (controller.hasClients && controller.position.hasViewportDimension) {
          final viewport = controller.position.viewportDimension;
          final itemCenter = index * extent + extent / 2 - controller.offset;
          final dist = ((itemCenter - viewport / 2).abs() / (viewport / 2))
              .clamp(0.0, 1.0);
          final falloff = dist * dist * strength;
          scale = 1 - 0.10 * falloff;
          opacity = 1 - 0.45 * falloff;
        }
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: math.max(scale, 0.85),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

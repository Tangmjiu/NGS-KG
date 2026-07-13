// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// Wear OS 圆屏可滚动列表 — 适配圆形屏幕的通用列表组件

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wear_plus/wear_plus.dart';
import 'package:wearable_rotary/wearable_rotary.dart';

/// Wear OS 圆屏通用可滚动列表。
///
/// 封装了 [ListView.builder] 并包含：
/// - 圆屏自动适配的左右内边距
/// - 大触控区域
/// - 可选的底部留空（避让 MiniPlayer）
/// - 可选的自动滚动到指定索引（用于歌词同步等场景）
class WatchScrollList extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ScrollController? controller;
  final double horizontalPadding;
  final double bottomPadding;

  /// 当设置此值时，列表会自动平滑滚动到该索引位置。
  /// 典型的用法是传入当前播放的歌词行索引。
  final int? autoScrollTo;

  /// [autoScrollTo] 的对齐方式。0.0 = 顶部对齐，0.5 = 居中对齐，1.0 = 底部对齐。
  /// 默认 0.35 使当前行略偏上，留出下方内容可视空间。
  final double autoScrollAlignment;

  const WatchScrollList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.horizontalPadding = 8.0,
    this.bottomPadding = 60.0,
    this.autoScrollTo,
    this.autoScrollAlignment = 0.35,
  });

  @override
  State<WatchScrollList> createState() => _WatchScrollListState();
}

class _WatchScrollListState extends State<WatchScrollList> {
  late final ScrollController _controller;
  bool _isUserScrolling = false;
  Timer? _userScrollResetTimer;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? RotaryScrollController();
  }

  @override
  void didUpdateWidget(WatchScrollList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当 autoScrollTo 变化且不是用户在手动滚动时，自动跳转
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
    // 用户停止滚动 3 秒后恢复自动同步
    _userScrollResetTimer = Timer(const Duration(seconds: 3), () {
      _isUserScrolling = false;
    });
  }

  void _scrollToIndex(int index) {
    // 估算每个 item 的高度约为 48px（含 padding），做粗略滚动
    const itemHeight = 48.0;
    final offset =
        index * itemHeight - widget.autoScrollAlignment * itemHeight;
    _controller.animateTo(
      offset.clamp(0.0, _controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRound = WatchShape.of(context) == WearShape.round;
    final hp = isRound ? widget.horizontalPadding + 4 : widget.horizontalPadding;

    return NotificationListener<ScrollNotification>(
      onNotification: (notif) {
        if (notif is UserScrollNotification) {
          _onUserScroll();
        }
        return false;
      },
      child: ListView.builder(
        controller: _controller,
        padding: EdgeInsets.fromLTRB(hp, 4, hp, widget.bottomPadding),
        itemCount: widget.itemCount,
        itemBuilder: widget.itemBuilder,
      ),
    );
  }
}

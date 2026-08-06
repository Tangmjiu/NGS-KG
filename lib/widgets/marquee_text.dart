// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 跑马灯文本（对标 Rhythm AutoScrollingTextOnDemand）
///
/// 文本超宽时自动横向滚动，两端渐隐遮罩；未超宽时退化为普通 [Text]。
/// 独立组件，不绑定任何业务（可复用于歌名、公告、通知等长文本场景）。
///
/// 特性：
/// - 速度按「逻辑像素/秒」配置，滚动距离自适应文本宽度
/// - 可选循环 / 单次滚动 / 滚动前延迟
/// - 两端线性渐隐（颜色默认取 `surface`，可自定义）
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  /// 滚动速度（逻辑像素/秒）
  final double speed;

  /// 是否循环滚动（false 时滚到末尾停在末尾）
  final bool repeat;

  /// 开始滚动前的延迟
  final Duration startDelay;

  /// 循环间隔（repeat 时回到起点前停留的时间）
  final Duration loopGap;

  /// 两端渐隐色（默认 `surface`，与页面背景一致时最自然）
  final Color? fadeColor;

  /// 渐隐宽度（逻辑像素）
  final double fadeWidth;

  /// 是否禁用滚动（强制静态，用于全局开关）
  final bool disableScroll;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.speed = 30,
    this.repeat = true,
    this.startDelay = const Duration(milliseconds: 600),
    this.loopGap = const Duration(milliseconds: 1200),
    this.fadeColor,
    this.fadeWidth = 20,
    this.disableScroll = false,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _overflow = 0;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addStatusListener(_onStatus);
    _start();
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.speed != widget.speed) {
      _started = false;
      _controller.stop();
      _start();
    }
  }

  void _start() {
    if (widget.disableScroll) return;
    Future.delayed(widget.startDelay, () {
      if (!mounted || _started) return;
      _started = true;
      _configureController();
    });
  }

  void _configureController() {
    if (!mounted || _overflow <= 0) return;
    final distance = _overflow + 48; // 末尾多滚一段，避免贴边
    _controller.duration = Duration(
      milliseconds: math.max(1, (distance / widget.speed * 1000).round()),
    );
    _controller.forward(from: 0);
  }

  void _onStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed) {
      if (widget.repeat) {
        Future.delayed(widget.loopGap, () {
          if (!mounted) return;
          _controller.forward(from: 0);
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 无滚动需求时直接用静态文本
    if (widget.disableScroll) {
      return Text(widget.text,
          style: widget.style,
          textAlign: widget.textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final style = widget.style ?? DefaultTextStyle.of(context).style;
        final tp = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();

        final available = constraints.maxWidth;
        _overflow = tp.width - available;

        // 未溢出：静态
        if (_overflow <= 0) {
          return Text(widget.text,
              style: widget.style,
              textAlign: widget.textAlign,
              maxLines: 1,
              overflow: TextOverflow.ellipsis);
        }

        // 溢出：滚动 + 渐隐遮罩
        final fade = widget.fadeColor ?? Theme.of(context).colorScheme.surface;
        final content = AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final dx = -_controller.value * (_overflow + 48);
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Text(
                widget.text,
                style: widget.style,
                textAlign: widget.textAlign,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
              ),
            );
          },
        );

        return ClipRect(
          child: ShaderMask(
            shaderCallback: (bounds) {
              final w = widget.fadeWidth;
              // dstOut：两端（不透明）扣出文本 → 渐隐；中间（透明）保留
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [fade, Colors.transparent, Colors.transparent, fade],
                stops: [0.0, w / bounds.width, 1 - w / bounds.width, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstOut,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: available,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      child: content,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

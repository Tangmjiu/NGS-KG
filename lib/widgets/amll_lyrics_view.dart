// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lyric/core/lyric_controller.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:flutter_lyric/core/lyric_style.dart';

/// AMLL (Apple Music-like Lyrics) 风格歌词视图。
///
/// 与 flutter_lyric 的 [LyricView]（单画布绘制）不同，本视图采用逐行
/// Widget 渲染，因此可以实现 AMLL 的标志性效果：
///
/// - **渐进模糊**：非焦点行随与焦点行的距离增加而逐渐高斯模糊，
///   由 `LyricStyle.fadeRange` 是否为空控制（即歌词设置里的模糊开关）。
/// - **间奏圆点**：相邻歌词行间隔 ≥ 4s（含长前奏）时，在下一行出现
///   的位置显示三点依次跳动动画，播放暂停时冻结。
/// - **精确锚定**：每行用 TextPainter 预测量高度，焦点行按
///   `activeAnchorPosition` 精确锚定滚动，不依赖经验行高估算。
///
/// 交互：点击任意行跳转播放；拖动浏览时显示中线 + 时间标签 + 播放按钮，
/// 松手 `activeAutoResumeDuration` 后自动回到焦点行。
class AmllLyricsView extends StatefulWidget {
  final LyricController controller;
  final LyricStyle style;

  /// 播放状态，用于驱动间奏圆点动画的播放/冻结。
  final bool isPlaying;

  const AmllLyricsView({
    super.key,
    required this.controller,
    required this.style,
    this.isPlaying = true,
  });

  @override
  State<AmllLyricsView> createState() => _AmllLyricsViewState();
}

/// 触发间奏动画的最小行间隔。
const _kMinInterludeGap = Duration(milliseconds: 4000);

/// 间奏结束提前量（下一行开唱前圆点提前消失）。
const _kInterludeTail = Duration(milliseconds: 250);

/// 长前奏也显示间奏圆点的最小阈值。
const _kMinIntroGap = Duration(milliseconds: 5000);

/// 渐进模糊：每距离一挡的 sigma 增量与上限。
const double _kBlurPerDistance = 1.2;
const double _kBlurMax = 4.0;

class _AmllLyricsViewState extends State<AmllLyricsView> {
  final ScrollController _scroll = ScrollController();

  List<LyricLine> _lines = const [];
  List<_LyricItem> _items = const [];
  int _activeIndex = 0;

  // 浏览（手动拖动）状态
  bool _browsing = false;
  int _browseIndex = 0;
  Timer? _resumeTimer;

  // 测量缓存的输入指纹
  double _measuredWidth = -1;
  TextDirection _measuredDirection = TextDirection.ltr;
  TextScaler _measuredScaler = TextScaler.noScaling;
  LyricStyle? _measuredStyle;
  List<LyricLine>? _measuredLines;

  double _viewportHeight = 0;
  bool _needsInitialJump = true;

  LyricController get controller => widget.controller;
  LyricStyle get style => widget.style;

  bool get _blurEnabled => style.fadeRange != null;

  @override
  void initState() {
    super.initState();
    _lines = controller.lyricNotifier.value?.lines ?? const [];
    _activeIndex = controller.activeIndexNotifiter.value;
    _rebuildItems();
    controller.lyricNotifier.addListener(_onLyricChanged);
    controller.activeIndexNotifiter.addListener(_onActiveChanged);
  }

  @override
  void dispose() {
    controller.lyricNotifier.removeListener(_onLyricChanged);
    controller.activeIndexNotifiter.removeListener(_onActiveChanged);
    _resumeTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  // ─── 数据：歌词模型与间奏项 ───

  void _onLyricChanged() {
    if (!mounted) return;
    setState(() {
      _lines = controller.lyricNotifier.value?.lines ?? const [];
      _activeIndex = controller.activeIndexNotifiter.value;
      _rebuildItems();
      _needsInitialJump = true;
    });
  }

  void _onActiveChanged() {
    if (!mounted) return;
    final next = controller.activeIndexNotifiter.value;
    if (next == _activeIndex) return;
    setState(() => _activeIndex = next);
    if (!_browsing) _scrollToActive();
  }

  /// 在行列表中插入间奏占位项（长间隔与长前奏）。
  void _rebuildItems() {
    final items = <_LyricItem>[];
    if (_lines.isNotEmpty && _lines.first.start >= _kMinIntroGap) {
      items.add(_InterludeItem(
        startMs: 0,
        endMs: (_lines.first.start - _kInterludeTail).inMilliseconds,
      ));
    }
    for (var i = 0; i < _lines.length; i++) {
      if (i > 0) {
        final gapStart = _lines[i - 1].end ?? _lines[i - 1].start;
        final gapEnd = _lines[i].start - _kInterludeTail;
        if (gapEnd > gapStart && gapEnd - gapStart >= _kMinInterludeGap) {
          items.add(_InterludeItem(
            startMs: gapStart.inMilliseconds,
            endMs: gapEnd.inMilliseconds,
          ));
        }
      }
      items.add(_LineItem(i));
    }
    _items = items;
  }

  // ─── 测量：逐行 TextPainter 预排版 ───

  void _ensureMeasured(
      double textWidth, TextDirection direction, TextScaler scaler) {
    if (textWidth == _measuredWidth &&
        direction == _measuredDirection &&
        scaler == _measuredScaler &&
        identical(style, _measuredStyle) &&
        identical(_lines, _measuredLines)) {
      return;
    }
    _measuredWidth = textWidth;
    _measuredDirection = direction;
    _measuredScaler = scaler;
    _measuredStyle = style;
    _measuredLines = _lines;

    // 参考行高：间奏占位行的高度（一行普通文本高）
    final refPainter = TextPainter(
      text: TextSpan(text: 'Ag', style: style.textStyle),
      textDirection: direction,
      textScaler: scaler,
    )..layout();
    final refLineHeight = refPainter.height;
    refPainter.dispose();

    var y = 0.0;
    for (final item in _items) {
      item.top = y;
      if (item is _LineItem) {
        item.height =
            _measureLine(_lines[item.index], textWidth, direction, scaler);
      } else {
        item.height = refLineHeight;
      }
      y += item.height + style.lineGap;
    }
  }

  double _measureLine(LyricLine line, double width, TextDirection direction,
      TextScaler scaler) {
    // 同时按普通/焦点样式测量取较大值，保证行高在焦点切换时不跳动
    double height = 0;
    for (final s in [style.textStyle, style.activeStyle]) {
      final p = TextPainter(
        text: TextSpan(text: line.text, style: s),
        textDirection: direction,
        textScaler: scaler,
        textAlign: style.lineTextAlign,
      )..layout(maxWidth: width);
      height = math.max(height, p.height);
      p.dispose();
    }
    if (line.translation != null && line.translation!.isNotEmpty) {
      final p = TextPainter(
        text: TextSpan(text: line.translation, style: style.translationStyle),
        textDirection: direction,
        textScaler: scaler,
        textAlign: style.lineTextAlign,
      )..layout(maxWidth: width);
      height += style.translationLineGap + p.height;
      p.dispose();
    }
    return height;
  }

  // ─── 滚动 ───

  double _scrollTargetForLine(int lineIndex) {
    for (final item in _items) {
      if (item is _LineItem && item.index == lineIndex) {
        // padding.top = 锚点像素值，因此滚动目标 = 行中心（内容坐标系）
        return math.max(0.0, item.top + item.height / 2);
      }
    }
    return 0;
  }

  void _scrollToActive({bool animate = true}) {
    if (!_scroll.hasClients || _viewportHeight <= 0) return;
    final target = _scrollTargetForLine(_activeIndex)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    if (animate) {
      _scroll.animateTo(target,
          duration: style.scrollDuration, curve: style.scrollCurve);
    } else {
      _scroll.jumpTo(target);
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _resumeTimer?.cancel();
      if (!_browsing) setState(() => _browsing = true);
      _updateBrowseIndex();
    } else if (notification is ScrollUpdateNotification) {
      if (_browsing) _updateBrowseIndex();
    } else if (notification is ScrollEndNotification) {
      if (_browsing) {
        _resumeTimer?.cancel();
        _resumeTimer = Timer(style.activeAutoResumeDuration, () {
          if (!mounted) return;
          setState(() => _browsing = false);
          _scrollToActive();
        });
      }
    }
    return false;
  }

  void _updateBrowseIndex() {
    if (!_scroll.hasClients || _items.isEmpty) return;
    final anchorPx = style.calcSelectionAnchorPosition(_viewportHeight);
    // padding.top = 播放锚点像素；浏览中线用选择锚点（0.5）
    final activePx = style.calcActiveAnchorPosition(_viewportHeight);
    final contentY = _scroll.offset + anchorPx - activePx;
    var best = 0;
    var bestDist = double.infinity;
    for (final item in _items) {
      if (item is! _LineItem) continue;
      final d = (item.top + item.height / 2 - contentY).abs();
      if (d < bestDist) {
        bestDist = d;
        best = item.index;
      }
    }
    if (best != _browseIndex) setState(() => _browseIndex = best);
  }

  void _seekToLine(int index) {
    if (index < 0 || index >= _lines.length) return;
    HapticFeedback.lightImpact();
    controller.setProgress(_lines[index].start);
    // 走 tapLine 事件，复用 PlayerScreen 注册的 seek 回调
    controller.notifyEvent(LyricEvent.tapLine, index);
  }

  // ─── 模糊 ───

  double _blurSigmaFor(int lineIndex) {
    if (!_blurEnabled) return 0;
    final focal = _browsing ? _browseIndex : _activeIndex;
    final distance = (lineIndex - focal).abs();
    if (distance == 0) return 0;
    return math.min(distance * _kBlurPerDistance, _kBlurMax);
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    if (_lines.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
        final scaler = MediaQuery.textScalerOf(context);
        final textWidth =
            constraints.maxWidth - style.contentPadding.horizontal;
        _ensureMeasured(textWidth, direction, scaler);
        _viewportHeight = constraints.maxHeight;

        if (_needsInitialJump) {
          _needsInitialJump = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToActive(animate: false);
          });
        }

        final activePx = style.calcActiveAnchorPosition(_viewportHeight);

        Widget list = NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: ListView.builder(
            controller: _scroll,
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.only(
              top: activePx,
              bottom: _viewportHeight - activePx,
            ),
            itemCount: _items.length,
            itemBuilder: _buildItem,
          ),
        );

        // 模糊开启时叠加上下边缘渐隐（fadeRange 由设置驱动）
        final fade = style.fadeRange;
        if (fade != null) {
          final topStop = fade.top <= 1 ? fade.top : fade.top / _viewportHeight;
          final bottomStop =
              fade.bottom <= 1 ? fade.bottom : fade.bottom / _viewportHeight;
          list = ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [
                Color(0x00FFFFFF),
                Color(0xFFFFFFFF),
                Color(0xFFFFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: [
                0.0,
                topStop.clamp(0.0, 1.0),
                (1 - bottomStop).clamp(0.0, 1.0),
                1.0,
              ],
            ).createShader(bounds),
            child: list,
          );
        }

        return Stack(
          children: [
            list,
            if (_browsing) ..._buildBrowsingOverlay(constraints),
          ],
        );
      },
    );
  }

  Widget _buildItem(BuildContext context, int itemIndex) {
    final item = _items[itemIndex];
    if (item is _InterludeItem) {
      return _InterludeRow(
        key: ValueKey('interlude_${item.startMs}'),
        item: item,
        height: item.height,
        isPlaying: widget.isPlaying,
        align: style.lineTextAlign,
        contentPadding: style.contentPadding,
        progressListenable: controller.progressNotifier,
      );
    }
    final lineItem = item as _LineItem;
    return _buildLineItem(lineItem);
  }

  Widget _buildLineItem(_LineItem item) {
    final index = item.index;
    final line = _lines[index];
    final isActive = index == _activeIndex;
    final hasTranslation =
        line.translation != null && line.translation!.isNotEmpty;
    final nextStart =
        index + 1 < _lines.length ? _lines[index + 1].start : null;

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: style.contentAlignment,
      children: [
        if (isActive)
          _ActiveLineText(
            line: line,
            style: style,
            nextStart: nextStart,
            progressListenable: controller.progressNotifier,
          )
        else
          Text(
            line.text,
            style: style.textStyle,
            textAlign: style.lineTextAlign,
          ),
        if (hasTranslation) ...[
          SizedBox(height: style.translationLineGap),
          Text(
            line.translation!,
            style: isActive && style.translationActiveColor != null
                ? style.translationStyle
                    .copyWith(color: style.translationActiveColor)
                : style.translationStyle,
            textAlign: style.lineTextAlign,
          ),
        ],
      ],
    );

    final sigma = _blurSigmaFor(index);
    if (sigma > 0.01) {
      content = TweenAnimationBuilder<double>(
        tween: Tween(end: sigma),
        duration: const Duration(milliseconds: 180),
        builder: (context, value, child) => ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: value, sigmaY: value),
          child: child,
        ),
        child: content,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _seekToLine(index),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: style.contentPadding.left),
        child: RepaintBoundary(child: content),
      ),
    );
  }

  /// 浏览模式：中线 + 时间标签 + 播放按钮
  List<Widget> _buildBrowsingOverlay(BoxConstraints constraints) {
    final anchorPx = style.calcSelectionAnchorPosition(_viewportHeight);
    final line = _browseIndex >= 0 && _browseIndex < _lines.length
        ? _lines[_browseIndex]
        : null;
    return [
      Positioned(
        top: anchorPx,
        left: 16,
        right: 16,
        child: IgnorePointer(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.25),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ),
      if (line != null)
        Positioned(
          top: anchorPx - 14,
          left: 24,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _formatDuration(line.start),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontFeatures: [ui.FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      if (line != null)
        Positioned(
          top: anchorPx - 18,
          right: 24,
          child: Material(
            color: Colors.white.withValues(alpha: 0.16),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                _resumeTimer?.cancel();
                setState(() => _browsing = false);
                _seekToLine(_browseIndex);
              },
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.play_arrow_rounded,
                    size: 20, color: Colors.white),
              ),
            ),
          ),
        ),
    ];
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ────────────────────────────────────────────────────────────
//  列表项模型
// ────────────────────────────────────────────────────────────

sealed class _LyricItem {
  double top = 0;
  double height = 0;
}

class _LineItem extends _LyricItem {
  final int index;
  _LineItem(this.index);
}

class _InterludeItem extends _LyricItem {
  final int startMs;
  final int endMs;
  _InterludeItem({required this.startMs, required this.endMs});
}

// ────────────────────────────────────────────────────────────
//  焦点行文本（扫光高亮，逐字优先）
// ────────────────────────────────────────────────────────────

class _ActiveLineText extends StatelessWidget {
  final LyricLine line;
  final LyricStyle style;
  final Duration? nextStart;
  final ValueNotifier<Duration> progressListenable;

  const _ActiveLineText({
    required this.line,
    required this.style,
    required this.nextStart,
    required this.progressListenable,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: progressListenable,
      builder: (context, position, _) {
        final words = line.words;
        if (words != null && words.isNotEmpty) {
          return Wrap(
            alignment: style.lineTextAlign == TextAlign.center
                ? WrapAlignment.center
                : WrapAlignment.start,
            children: [
              for (final w in words)
                _SweepText(
                  text: w.text,
                  baseStyle: style.textStyle,
                  activeStyle: style.activeStyle,
                  progress: _wordProgress(w, position),
                ),
            ],
          );
        }
        final end =
            line.end ?? nextStart ?? line.start + const Duration(seconds: 3);
        final spanMs = math.max(1, (end - line.start).inMilliseconds);
        final p =
            ((position - line.start).inMilliseconds / spanMs).clamp(0.0, 1.0);
        return _SweepText(
          text: line.text,
          baseStyle: style.textStyle,
          activeStyle: style.activeStyle,
          progress: p,
          textAlign: style.lineTextAlign,
          center: style.lineTextAlign == TextAlign.center,
        );
      },
    );
  }

  double _wordProgress(LyricWord word, Duration position) {
    final startMs = word.start.inMilliseconds;
    final endMs = word.end?.inMilliseconds ?? startMs;
    final cur = position.inMilliseconds;
    if (cur <= startMs) return 0;
    if (endMs <= startMs || cur >= endMs) return 1;
    return (cur - startMs) / (endMs - startMs);
  }
}

/// 双层文本扫光：底层为普通样式，上层焦点样式按 [progress] 从左到右点亮。
class _SweepText extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;
  final TextStyle activeStyle;
  final double progress;
  final TextAlign textAlign;
  final bool center;

  const _SweepText({
    required this.text,
    required this.baseStyle,
    required this.activeStyle,
    required this.progress,
    this.textAlign = TextAlign.start,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    const tail = 0.08; // 扫光尾迹软化宽度（相对值）
    final p = progress.clamp(0.0, 1.0);
    final softStart = (p - tail).clamp(0.0, 1.0);
    return Stack(
      alignment: center ? Alignment.center : Alignment.centerLeft,
      children: [
        Text(text, style: baseStyle, textAlign: textAlign),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
              Color(0x00FFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: [0.0, softStart, p, 1.0],
          ).createShader(bounds),
          child: Text(text, style: activeStyle, textAlign: textAlign),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
//  间奏圆点行
// ────────────────────────────────────────────────────────────

class _InterludeRow extends StatefulWidget {
  final _InterludeItem item;
  final double height;
  final bool isPlaying;
  final TextAlign align;
  final EdgeInsets contentPadding;
  final ValueNotifier<Duration> progressListenable;

  const _InterludeRow({
    super.key,
    required this.item,
    required this.height,
    required this.isPlaying,
    required this.align,
    required this.contentPadding,
    required this.progressListenable,
  });

  @override
  State<_InterludeRow> createState() => _InterludeRowState();
}

class _InterludeRowState extends State<_InterludeRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  bool get _inGap {
    final pos = widget.progressListenable.value.inMilliseconds;
    return pos >= widget.item.startMs && pos < widget.item.endMs;
  }

  @override
  void initState() {
    super.initState();
    _syncAnimation();
    widget.progressListenable.addListener(_syncAnimation);
  }

  @override
  void didUpdateWidget(covariant _InterludeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progressListenable != widget.progressListenable) {
      oldWidget.progressListenable.removeListener(_syncAnimation);
      widget.progressListenable.addListener(_syncAnimation);
    }
    _syncAnimation();
  }

  @override
  void dispose() {
    widget.progressListenable.removeListener(_syncAnimation);
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation() {
    final shouldRun = _inGap && widget.isPlaying;
    if (shouldRun && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldRun && _controller.isAnimating) {
      // 暂停时冻结当前相位；离开间奏时归零
      if (!_inGap) {
        _controller.stop();
        _controller.value = 0;
      } else {
        _controller.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _inGap;
    final alignment = widget.align == TextAlign.center
        ? Alignment.center
        : Alignment.centerLeft;
    return SizedBox(
      height: widget.height,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: EdgeInsets.only(left: widget.contentPadding.left + 2),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++) _buildDot(i),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 单点脉冲：相位错开 0.22 周期，前半程 easeOutBack 弹起、后半程回落，
  /// 形成三点依次跳动的波浪效果。
  Widget _buildDot(int i) {
    var t = (_controller.value - i * 0.22) % 1.0;
    if (t < 0) t += 1.0;
    double p;
    if (t < 0.45) {
      p = Curves.easeOutBack.transform(t / 0.45).clamp(0.0, 1.15);
    } else {
      p = 1 - Curves.easeIn.transform((t - 0.45) / 0.55);
    }
    final scale = 0.55 + 0.5 * p;
    final opacity = (0.3 + 0.7 * p).clamp(0.0, 1.0);
    return Transform.translate(
      offset: Offset(0, -2.5 * p),
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

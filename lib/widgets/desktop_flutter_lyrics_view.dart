// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:provider/provider.dart';

import '../models/lyric_settings.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';

/// 桌面全屏播放器歌词视图 —— Android 端成熟的 flutter_lyric 方案。
///
/// 直接使用官方 `LyricView`（CustomPaint + TextPainter 精确测量行高与
/// 锚点，歌词滚动与播放位置严格对齐），样式参数与移动端一致：
/// - 翻译行由 [LyricView] 渲染（歌词模型 [LyricModel.lines] 携带）
/// - 罗马音开关行为与 Android 端一致（开关状态保留，渲染由模型决定）
/// - 间奏动画保留（相邻歌词行间隔 ≥ 4s 时三圆点呼吸，见 [_InterludeDots]）
/// - 布局沿用 [DesktopFullscreenPlayer] 的歌词区域，不改变现有布局
class DesktopFlutterLyricsView extends StatefulWidget {
  const DesktopFlutterLyricsView({super.key});

  @override
  State<DesktopFlutterLyricsView> createState() =>
      _DesktopFlutterLyricsViewState();
}

class _DesktopFlutterLyricsViewState extends State<DesktopFlutterLyricsView> {
  /// 焦点行锚点（视口高度比例），与 AMLL 视觉一致。
  static const double _kAnchor = 0.35;

  @override
  void initState() {
    super.initState();
    // 与 Android 端一致：点击歌词行跳转播放
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final player = context.read<PlayerProvider>();
      player.lyricController.setOnTapLineCallback(
        (duration) => player.seek(duration),
      );
    });
  }

  LyricStyle _buildLyricStyle(LyricSettings ls) {
    // 焦点行字重 = 用户设置 + 200（确保比普通行重，与移动端一致）
    final int activeWeightIdx = ((ls.fontWeight / 100).round() + 2).clamp(3, 8);
    final activeWeight = FontWeight.values[activeWeightIdx];
    // 桌面全屏深色背景用白色系；桌面字号按 1.8 放大（沿用原桌面视觉比例）
    final double fs = ls.fontSize * 1.8;
    return LyricStyle(
      textStyle: TextStyle(
        fontSize: fs,
        fontWeight: ls.resolvedWeight,
        height: 1.6,
        color: Colors.white.withValues(alpha: 0.5),
      ),
      // 焦点行同字号杜绝折行，但加粗 + 白色 + 字间距确保视觉突出
      activeStyle: TextStyle(
        fontSize: fs,
        fontWeight: activeWeight,
        height: 1.4,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
      // 翻译用字号区分，不用粗细
      translationStyle: TextStyle(
        fontSize: ls.translationFontSize * 1.8,
        fontWeight: ls.resolvedWeight,
        height: 1.3,
        color: Colors.white.withValues(alpha: 0.4),
      ),
      translationActiveColor: Colors.white70,
      lineGap: 24,
      translationLineGap: 4,
      lineTextAlign: ls.centerAlign ? TextAlign.center : TextAlign.left,
      contentAlignment:
          ls.centerAlign ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      contentPadding: const EdgeInsets.symmetric(horizontal: 28),
      selectionAnchorPosition: 0.5,
      selectionAlignment: MainAxisAlignment.center,
      // 焦点行锚点保持原 AMLL 视图的 0.35，不改变现有布局观感
      activeAnchorPosition: _kAnchor,
      activeAlignment: MainAxisAlignment.center,
      activeHighlightColor: Colors.white,
      activeHighlightExtraFadeWidth: 14,
      selectedColor: Colors.white.withValues(alpha: 0.8),
      selectedTranslationColor: Colors.white.withValues(alpha: 0.8),
      scrollDuration: const Duration(milliseconds: 400),
      scrollCurve: Curves.easeInOutCubic,
      scrollDurations: {},
      enableSwitchAnimation: true,
      switchEnterDuration: const Duration(milliseconds: 200),
      switchExitDuration: const Duration(milliseconds: 200),
      switchEnterCurve: Curves.easeIn,
      switchExitCurve: Curves.easeOut,
      selectionAutoResumeMode: SelectionAutoResumeMode.selecting,
      selectionAutoResumeDuration: const Duration(milliseconds: 500),
      activeAutoResumeDuration: const Duration(milliseconds: 3000),
      // 上下渐隐范围：仅 blurEffect 开启时生效
      fadeRange: ls.blurEffect ? FadeRange(top: 0.15, bottom: 0.15) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 歌词设置变化时刷新样式（低频，可整体重建）
    final ls = context.watch<ThemeProvider>().lyricSettings;
    final player = context.read<PlayerProvider>();
    return Selector<PlayerProvider, ({int selectedLyricLang, Song? song})>(
      selector: (_, p) => (
        selectedLyricLang: p.selectedLyricLang,
        song: p.currentSong,
      ),
      builder: (context, state, _) {
        final model = player.lyricController.lyricNotifier.value;
        final hasLyrics = model != null && model.lines.isNotEmpty;
        if (!hasLyrics) return const SizedBox.shrink();
        return Stack(
          fit: StackFit.expand,
          children: [
            LyricView(
              key: ValueKey(
                'desktop_lyrics_${state.selectedLyricLang}_'
                '${state.song?.hash ?? state.song?.id}',
              ),
              controller: player.lyricController,
              style: _buildLyricStyle(ls),
            ),
            // AMLL 风格间奏动画（独立订阅 position，不影响 LyricView）
            _InterludeOverlay(
              controller: player.lyricController,
              anchor: _kAnchor,
            ),
          ],
        );
      },
    );
  }
}

/// AMLL 风格间奏动画层。
///
/// 相邻歌词行间隔 ≥ 4s 视为间奏：播放进入该区间时，在歌词锚点下方显示
/// 三圆点依次点亮 + 呼吸缩放动画（参照 amll-lyrics-fact interludeDots）。
class _InterludeOverlay extends StatefulWidget {
  final LyricController controller;
  final double anchor;

  const _InterludeOverlay({
    required this.controller,
    required this.anchor,
  });

  @override
  State<_InterludeOverlay> createState() => _InterludeOverlayState();
}

class _InterludeOverlayState extends State<_InterludeOverlay> {
  List<_Interlude> _interludes = const [];

  @override
  void initState() {
    super.initState();
    _rebuildInterludes();
    widget.controller.lyricNotifier.addListener(_rebuildInterludes);
  }

  @override
  void didUpdateWidget(covariant _InterludeOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.lyricNotifier.removeListener(_rebuildInterludes);
      _rebuildInterludes();
      widget.controller.lyricNotifier.addListener(_rebuildInterludes);
    }
  }

  @override
  void dispose() {
    widget.controller.lyricNotifier.removeListener(_rebuildInterludes);
    super.dispose();
  }

  void _rebuildInterludes() {
    final lines =
        widget.controller.lyricNotifier.value?.lines ?? const <LyricLine>[];
    final next = _computeInterludes(lines);
    if (listEquals(next, _interludes)) return;
    _interludes = next;
    if (mounted) setState(() {});
  }

  /// AMLL 间奏判定：前一行结束 → 后一行开始(提前 250ms) 间隔 ≥ 4s。
  static List<_Interlude> _computeInterludes(List<LyricLine> lines) {
    final result = <_Interlude>[];
    for (var i = 0; i + 1 < lines.length; i++) {
      final gapStart = lines[i].end ?? lines[i].start;
      final gapEnd = lines[i + 1].start - const Duration(milliseconds: 250);
      if (gapEnd - gapStart >= const Duration(milliseconds: 4000)) {
        result.add(_Interlude(
          startMs: gapStart.inMilliseconds,
          endMs: gapEnd.inMilliseconds,
        ));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final posMs = player.position.inMilliseconds;
        _Interlude? active;
        for (final il in _interludes) {
          if (posMs >= il.startMs && posMs < il.endMs) {
            active = il;
            break;
          }
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                if (active != null)
                  Positioned(
                    // 锚点下方约一个行高处（原 AMLL 间奏行紧跟当前行的位置）
                    top: constraints.maxHeight * widget.anchor + 28,
                    left: 0,
                    right: 0,
                    child: _InterludeDots(
                      active: true,
                      isPlaying: player.isPlaying,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Interlude {
  final int startMs;
  final int endMs;

  const _Interlude({required this.startMs, required this.endMs});

  @override
  bool operator ==(Object other) =>
      other is _Interlude && other.startMs == startMs && other.endMs == endMs;

  @override
  int get hashCode => Object.hash(startMs, endMs);
}

/// 间奏等候动画：三圆点依次点亮 + 呼吸缩放（AMLL interludeDots）。
class _InterludeDots extends StatefulWidget {
  final bool active;
  final bool isPlaying;

  const _InterludeDots({
    required this.active,
    required this.isPlaying,
  });

  @override
  State<_InterludeDots> createState() => _InterludeDotsState();
}

class _InterludeDotsState extends State<_InterludeDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    // 初始即为激活态时直接启动（例如 seek 跳进间奏区）
    if (widget.active && widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _InterludeDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && widget.isPlaying) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    const dotSize = 6.0;
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final breath = 1 + 0.05 * math.sin(2 * math.pi * t);
          double dotOpacity(int i) {
            final v = (t * 3 - i).clamp(0.0, 1.0);
            return 0.25 + v * 0.75;
          }

          return Transform.scale(
            scale: 0.7 * breath,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: dotSize,
                    height: dotSize,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: dotOpacity(i).clamp(0.0, 1.0),
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

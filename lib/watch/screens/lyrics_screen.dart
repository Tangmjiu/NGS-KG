// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 手表歌词屏 — 滚动歌词 + 翻译开关 + 点击行跳转进度 + 表冠滚动

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_model.dart' show LyricLine;
import 'package:provider/provider.dart';
import 'package:wearable_rotary/wearable_rotary.dart';

import '../../../providers/player_provider.dart';
import '../utils/watch_layout.dart';
import '../widgets/round_safe_area.dart';
import '../widgets/watch_scaffold.dart';

/// 手表端歌词屏幕。
///
/// - 逐行精确测量 + 焦点行锚定滚动
/// - 翻译开关（右上角图标）
/// - 点击歌词行跳转播放进度
/// - 表冠滚动
class WatchLyricsScreen extends StatefulWidget {
  const WatchLyricsScreen({super.key});

  @override
  State<WatchLyricsScreen> createState() => _WatchLyricsScreenState();
}

class _WatchLyricsScreenState extends State<WatchLyricsScreen> {
  final _scrollController = RotaryScrollController();
  List<LyricLine> _lines = const [];
  int _lastActive = -1;
  bool _showTranslation = true;

  List<double> _offsets = const [];
  List<double> _heights = const [];
  List<LyricLine>? _measuredLines;
  double _measuredWidth = -1;

  static const _lineGap = 6.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureMeasured(List<LyricLine> lines, double width) {
    if (identical(lines, _measuredLines) && width == _measuredWidth) return;
    _measuredLines = lines;
    _measuredWidth = width;

    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final scaler = MediaQuery.textScalerOf(context);
    final offsets = <double>[];
    final heights = <double>[];
    var y = 0.0;
    for (final line in lines) {
      offsets.add(y);
      var h = 0.0;
      for (final style in [_lineStyle(false), _lineStyle(true)]) {
        final painter = TextPainter(
          text: TextSpan(text: line.text, style: style),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 2,
        )..layout(maxWidth: width);
        h = math.max(h, painter.height);
        painter.dispose();
      }
      if (_showTranslation &&
          line.translation != null &&
          line.translation!.isNotEmpty) {
        final painter = TextPainter(
          text: TextSpan(text: line.translation, style: _translationStyle),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout(maxWidth: width);
        h += 2 + painter.height;
        painter.dispose();
      }
      heights.add(h);
      y += h + _lineGap;
    }
    _offsets = offsets;
    _heights = heights;
  }

  TextStyle _lineStyle(bool active) => TextStyle(
        fontSize: active ? 14 : 12,
        fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        height: 1.5,
      );

  TextStyle get _translationStyle => const TextStyle(fontSize: 10, height: 1.3);

  void _scrollToActive(int index, {bool animate = true}) {
    if (!_scrollController.hasClients || index < 0 || index >= _offsets.length)
      return;
    final viewport = _scrollController.position.viewportDimension;
    final target = _offsets[index] + _heights[index] / 2 - viewport * 0.5;
    final clamped =
        target.clamp(0.0, _scrollController.position.maxScrollExtent);
    if (animate) {
      _scrollController.animateTo(clamped,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic);
    } else {
      _scrollController.jumpTo(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    final cs = Theme.of(context).colorScheme;
    final textWidth = layout.diameter - layout.listHorizontal * 2 - 24;

    return WatchScaffold(
      showTime: false,
      body: Consumer<PlayerProvider>(
        builder: (context, player, _) {
          final model = player.lyricController.lyricNotifier.value;
          final lines = model?.lines ?? const <LyricLine>[];
          final activeIdx = player.lyricController.activeIndexNotifiter.value;

          if (lines.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lyrics_rounded,
                      size: 32, color: cs.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 8),
                  Text('暂无歌词',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                      )),
                ],
              ),
            );
          }

          return Stack(
            children: [
              _buildLyricsList(lines, activeIdx, textWidth, layout, player),
              // 翻译开关（右上角）
              Positioned(
                top: 2,
                right: 6,
                child: _TranslationToggle(
                  show: _showTranslation,
                  onToggle: () {
                    setState(() {
                      _showTranslation = !_showTranslation;
                      _measuredLines = null; // 强制重新测量
                    });
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLyricsList(
    List<LyricLine> lines,
    int activeIdx,
    double textWidth,
    WatchLayout layout,
    PlayerProvider player,
  ) {
    _ensureMeasured(lines, textWidth);

    // 每次 rebuild 都对齐焦点行到屏幕正中，彻底消除漂移
    if (_lines != lines) {
      _lines = lines;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToActive(activeIdx, animate: false);
      });
    } else if (_lastActive != activeIdx) {
      _lastActive = activeIdx;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToActive(activeIdx);
      });
    } else {
      // 焦点行没变但可能因 rebuild 导致偏移，强制对齐
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToActive(activeIdx, animate: false);
      });
    }

    final cs = Theme.of(context).colorScheme;

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x00FFFFFF),
          Color(0xFFFFFFFF),
          Color(0xFFFFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: [0.0, 0.12, 0.88, 1.0],
      ).createShader(bounds),
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.fromLTRB(
          layout.listHorizontal,
          0,
          layout.listHorizontal,
          layout.bottomInset + 16,
        ),
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          final isActive = index == activeIdx;
          return GestureDetector(
            onTap: () {
              player.seek(line.start);
              player.lyricController.setProgress(line.start);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: _lineGap / 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: _lineStyle(isActive).copyWith(
                      color: isActive
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.55),
                    ),
                    child: Text(
                      line.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isActive &&
                      _showTranslation &&
                      line.translation != null &&
                      line.translation!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        line.translation!,
                        style: _translationStyle.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.45),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 翻译开关按钮（右上角浮动）
class _TranslationToggle extends StatelessWidget {
  final bool show;
  final VoidCallback onToggle;

  const _TranslationToggle({required this.show, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: show ? '关闭翻译' : '开启翻译',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              show ? Icons.translate_rounded : Icons.translate_outlined,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

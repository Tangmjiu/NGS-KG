// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ym_lyric/model/krc_lyric_line_model.dart';

import '../models/lyric_settings.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';

/// 桌面全屏播放器歌词视图（AMLL 布局 + 简洁行高亮动效）。
///
/// 纯 Flutter 实现（无 amlv/WebView）：
/// - 锚点：当前行固定视口 35% 高度（AMLL `alignPosition: 0.35`）
/// - 行状态：当前行白色加粗，其余行按已唱/未唱降低透明度，
///   颜色平滑过渡（无逐字扫光/缩放/模糊，与移动端风格一致）
/// - 间奏：相邻歌词行间隔 ≥ 4s 时插入三圆点呼吸等候动画
/// - 交互：点击行 seek；鼠标滚轮或按住拖拽浏览歌词时显示
///   锚点中线/目标行时间/播放按钮，停止操作 3.5s 后自动跟随播放行
class DesktopAmllLyricsView extends StatefulWidget {
  const DesktopAmllLyricsView({super.key});

  @override
  State<DesktopAmllLyricsView> createState() => _DesktopAmllLyricsViewState();
}

/// 颜色过渡动效 token：快速启动 → 平滑收尾。
const Duration _kSpringDuration = Duration(milliseconds: 500);
const Curve _kSpringCurve = Curves.easeOutExpo;
const Duration _kScrollDuration = Duration(milliseconds: 550);

class _DesktopAmllLyricsViewState extends State<DesktopAmllLyricsView> {
  static const double _anchor = 0.35;

  final ScrollController _scrollController = ScrollController();

  late final PlayerProvider _player;
  ThemeProvider? _themeProvider;

  LyricSettings _settings = LyricSettings.defaults;
  List<_LyricRow> _rows = const [];
  List<_Item> _items = const [];
  List<int> _lyricToItem = const [];
  List<int> _itemToLyric = const [];
  List<_Interlude> _interludes = const [];

  int _activeIndex = 0;
  int _centerItemIndex = 0;
  int _lastSongId = -1;
  String _lastFingerprint = '';
  bool _hasSecondary = false;
  bool _isUserDragging = false;
  bool _programmaticScroll = false;
  Timer? _dragEndTimer;
  _Interlude? _activeInterlude;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = context.read<PlayerProvider>();
    _themeProvider = context.read<ThemeProvider>();
    _settings = _themeProvider?.lyricSettings ?? LyricSettings.defaults;
    _player.addListener(_onPlayerUpdate);
    _themeProvider?.addListener(_onThemeUpdate);
    // 首次挂载时同步一次（可能歌词已加载完成）
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPlayerUpdate());
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayerUpdate);
    _themeProvider?.removeListener(_onThemeUpdate);
    _dragEndTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onThemeUpdate() {
    if (!mounted) return;
    final tp = _themeProvider;
    if (tp == null) return;
    final next = tp.lyricSettings;
    if (next == _settings) return;
    setState(() => _settings = next);
  }

  /// 歌词内容指纹：歌曲 id + KRC/LRC 行数 + 首尾时间 + 语言/翻译/罗马音状态。
  String _fingerprint() {
    final songId = _player.currentSong?.id ?? -1;
    final lines = _player.krcLines;
    if (lines != null && lines.isNotEmpty) {
      return '$songId:${lines.length}:'
          '${lines.first.startTime}:${lines.last.startTime}:'
          '${_player.selectedLyricLang}:'
          '${_player.showTranslation}:${_player.showRomaji}';
    }
    // LRC 兜底：用 LyricModel 行数做指纹（异步加载完成后触发重建）
    final model = _player.lyricController.lyricNotifier.value;
    final count = model?.lines.length ?? 0;
    return '$songId:lrc:$count:'
        '${_player.selectedLyricLang}:'
        '${_player.showTranslation}:${_player.showRomaji}';
  }

  void _onPlayerUpdate() {
    if (!mounted) return;
    final songId = _player.currentSong?.id;
    final fp = _fingerprint();
    final rebuilt = songId != _lastSongId || fp != _lastFingerprint;
    if (rebuilt) {
      _lastSongId = songId ?? -1;
      _lastFingerprint = fp;
      _rebuildItems();
    }

    final posMs = _player.position.inMilliseconds;
    final newIndex = _indexFor(posMs);
    final newInterlude = _activeInterludeFor(posMs);
    final newPlaying = _player.isPlaying;
    final stateChanged = newIndex != _activeIndex ||
        newInterlude != _activeInterlude ||
        newPlaying != _isPlaying;
    if (!stateChanged) return;

    setState(() {
      _activeIndex = newIndex;
      _activeInterlude = newInterlude;
      _isPlaying = newPlaying;
    });
    if (!_isUserDragging) {
      _scrollToIndex(newIndex, immediate: rebuilt);
    }
  }

  void _rebuildItems() {
    final rows = _buildRows();
    _rows = rows;
    _activeIndex = 0;
    _centerItemIndex = 0;
    _activeInterlude = null;
    _hasSecondary = (_player.showTranslation && _player.hasLangData) ||
        (_player.showRomaji && _player.hasRomajiData);

    final items = <_Item>[];
    final lyricToItem = <int>[];
    final itemToLyric = <int>[];
    final interludes = <_Interlude>[];
    for (var i = 0; i < rows.length; i++) {
      lyricToItem.add(items.length);
      itemToLyric.add(i);
      items.add(_Item.row(rows[i]));
      if (i + 1 < rows.length) {
        // AMLL 间奏判定：前一行结束 → 后一行开始(提前 250ms) 间隔 ≥ 4s
        final gapStart = rows[i].endMs;
        final gapEnd = rows[i + 1].startMs - 250;
        if (gapEnd - gapStart >= 4000) {
          final il = _Interlude(
            startMs: gapStart,
            endMs: gapEnd,
            anchorIndex: i,
          );
          interludes.add(il);
          itemToLyric.add(il.anchorIndex);
          items.add(_Item.interlude(il));
        }
      }
    }
    _items = items;
    _lyricToItem = lyricToItem;
    _itemToLyric = itemToLyric;
    _interludes = interludes;
  }

  /// KRC 行 → 视图行（跳过空行；翻译/罗马音按行索引对齐拼入）。
  /// KRC 无数据（仅 LRC 歌词）时降级为 LyricModel 纯文本行。
  List<_LyricRow> _buildRows() {
    final krc = _player.krcLines;
    if (krc != null && krc.isNotEmpty) {
      return _buildKrcRows(krc);
    }

    // ── LRC 兜底：无逐字数据时用 LyricModel 构建纯文本行 ──
    final model = _player.lyricController.lyricNotifier.value;
    if (model == null || model.lines.isEmpty) return const [];
    final List<String>? trans = _player.showTranslation
        ? _player.lyricLangMap[_player.selectedLyricLang]
        : null;
    final List<String>? roma =
        _player.showRomaji && _player.selectedLyricLang != 1
            ? _player.lyricLangMap[1]
            : null;
    final lrcRows = <_LyricRow>[];
    for (var i = 0; i < model.lines.length; i++) {
      final line = model.lines[i];
      final text = line.text.trim();
      if (text.isEmpty) continue;
      lrcRows.add(_LyricRow(
        startMs: line.start.inMilliseconds,
        endMs: (line.end ?? line.start + const Duration(seconds: 4))
            .inMilliseconds,
        text: text,
        words: const [],
        translation:
            trans != null && i < trans.length ? _nonEmpty(trans[i]) : null,
        romaji: roma != null && i < roma.length ? _nonEmpty(roma[i]) : null,
      ));
    }
    return lrcRows;
  }

  /// 从 KRC 数据构建视图行。
  List<_LyricRow> _buildKrcRows(List<KrcLyricLineModel> krc) {
    final List<String>? trans = _player.showTranslation
        ? _player.lyricLangMap[_player.selectedLyricLang]
        : null;
    final List<String>? roma =
        _player.showRomaji && _player.selectedLyricLang != 1
            ? _player.lyricLangMap[1]
            : null;

    final rows = <_LyricRow>[];
    for (var i = 0; i < krc.length; i++) {
      final line = krc[i];
      String text;
      try {
        text = line.getWordLine();
      } catch (_) {
        continue;
      }
      if (text.trim().isEmpty) continue;

      final words = <_LyricWord>[];
      final sub = line.line;
      if (sub != null) {
        for (final w in sub) {
          final word = w.word;
          if (word == null || word.isEmpty) continue;
          final ws = (w.startTime ?? 0) + line.startTime;
          final we = ws + (w.duration ?? 0);
          words.add(_LyricWord(text: word, startMs: ws, endMs: we));
        }
      }

      rows.add(_LyricRow(
        startMs: line.startTime,
        endMs: line.startTime + line.duration,
        text: text,
        words: words,
        translation:
            trans != null && i < trans.length ? _nonEmpty(trans[i]) : null,
        romaji: roma != null && i < roma.length ? _nonEmpty(roma[i]) : null,
      ));
    }
    return rows;
  }

  String? _nonEmpty(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  /// 定位当前时间对应的歌词行索引（_rows 按时间有序）。
  int _indexFor(int posMs) {
    if (_rows.isEmpty) return 0;
    var idx = 0;
    for (var i = 0; i < _rows.length; i++) {
      if (_rows[i].startMs <= posMs) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  _Interlude? _activeInterludeFor(int posMs) {
    for (final il in _interludes) {
      if (posMs >= il.startMs && posMs < il.endMs) return il;
    }
    return null;
  }

  /// 行高（固定 itemExtent，滚动锚点计算精确）。
  ///
  /// 精确按当前实际渲染内容计算：
  /// - 主歌词行最多折 2 行（长句不截断，避免 BOTTOM OVERFLOWED）
  /// - 翻译/罗马音副行按实际开启数量逐一加高（开关切换瞬间不溢出）
  double get _itemExtent {
    final baseFontSize = _settings.fontSize * 1.8;
    final main = baseFontSize * 1.5 * 2; // 主行最多 2 行
    final secondaryCount =
        ((_player.showTranslation && _player.hasLangData) ? 1 : 0) +
            ((_player.showRomaji && _player.hasRomajiData) ? 1 : 0);
    final secondary =
        secondaryCount * (baseFontSize * 0.5 * 1.5 + 4); // 副行 + 行距
    final pad = baseFontSize * 0.6;
    return (main + secondary + pad).clamp(90.0, 380.0);
  }

  /// 将第 [index] 个歌词行滚动到视口锚点（padding 顶部 = 0.35 视口高）。
  void _scrollToIndex(int index, {bool immediate = false}) {
    if (!_scrollController.hasClients || _rows.isEmpty) return;
    final itemIndex = index < _lyricToItem.length ? _lyricToItem[index] : 0;
    final max = _scrollController.position.maxScrollExtent;
    final target = (itemIndex * _itemExtent).clamp(0.0, max);
    // 标记程序性滚动：_onScrollNotification 借此区分"自动跟随"与"用户滚轮"，
    // 避免自动跟随滚动被误判为用户浏览导致歌词被拉回。
    _programmaticScroll = true;
    if (immediate) {
      _scrollController.jumpTo(target);
      _programmaticScroll = false;
    } else {
      // AMLL 滚动：spring 感平滑滚动（快速启动、缓慢锚定）
      _scrollController
          .animateTo(
            target,
            duration: _kScrollDuration,
            curve: _kSpringCurve,
          )
          .whenComplete(() => _programmaticScroll = false);
    }
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (n is ScrollStartNotification) {
      if (n.dragDetails != null) {
        // 鼠标/触摸按住拖拽
        _dragEndTimer?.cancel();
        setState(() => _isUserDragging = true);
      } else if (!_programmaticScroll) {
        // 鼠标滚轮滚动 → 进入用户浏览模式（暂停自动跟随，显示锚点/时间）
        _dragEndTimer?.cancel();
        setState(() => _isUserDragging = true);
      }
    } else if (n is ScrollUpdateNotification) {
      if (_isUserDragging) {
        _updateCenterItemIndex();
      }
    } else if (n is ScrollEndNotification) {
      if (_isUserDragging) {
        _dragEndTimer?.cancel();
        _dragEndTimer = Timer(const Duration(milliseconds: 3500), () {
          if (!mounted) return;
          setState(() => _isUserDragging = false);
          _scrollToIndex(_activeIndex);
        });
      }
    }
    return false;
  }

  void _updateCenterItemIndex() {
    if (!_scrollController.hasClients || _items.isEmpty) return;
    final viewport = _scrollController.position.viewportDimension;
    final idx = ((_scrollController.offset + viewport * _anchor) / _itemExtent)
        .round()
        .clamp(0, _items.length - 1);
    if (idx != _centerItemIndex) {
      setState(() => _centerItemIndex = idx);
    }
  }

  void _seekToCenter() {
    if (_centerItemIndex < 0 || _centerItemIndex >= _items.length) return;
    final item = _items[_centerItemIndex];
    final row = item.row;
    if (row != null) {
      _player.seek(Duration(milliseconds: row.startMs));
    } else if (item.interlude != null) {
      final anchor = item.interlude!.anchorIndex;
      if (anchor >= 0 && anchor < _rows.length) {
        _player.seek(Duration(milliseconds: _rows[anchor].endMs));
      }
    }
    setState(() => _isUserDragging = false);
    _scrollToIndex(_activeIndex);
  }

  String _centerTimeText() {
    final item = _items[_centerItemIndex];
    final row = item.row;
    if (row != null) return _fmt(row.startMs);
    if (item.interlude != null) {
      return _fmt(item.interlude!.startMs);
    }
    return '00:00';
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportH = constraints.maxHeight;
        Widget content = Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                // 顶部留 0.35 视口高：当前行滚到该处即视觉锚点
                padding: EdgeInsets.only(
                  top: viewportH * _anchor,
                  bottom: viewportH * (1 - _anchor),
                ),
                itemExtent: _itemExtent,
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  if (item.isInterlude) {
                    return _InterludeDotsRow(
                      active: _activeInterlude == item.interlude,
                      isPlaying: _isPlaying,
                      // 跟随歌词对齐方式与字号
                      alignment: _settings.centerAlign
                          ? Alignment.center
                          : Alignment.centerLeft,
                      dotSize: _settings.fontSize * 1.2,
                    );
                  }
                  final row = item.row!;
                  final lyricIndex =
                      index < _itemToLyric.length ? _itemToLyric[index] : 0;
                  final isActive = lyricIndex == _activeIndex;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        _player.seek(Duration(milliseconds: row.startMs)),
                    child: _AmllLyricRow(
                      key: ValueKey(lyricIndex),
                      row: row,
                      isActive: isActive,
                      played: lyricIndex < _activeIndex,
                      distance: (lyricIndex - _activeIndex).abs(),
                      settings: _settings,
                    ),
                  );
                },
              ),
            ),

            // ── 手动拖拽时：锚点中线 (AMLL 精髓) ──
            if (_isUserDragging)
              Positioned(
                left: 0,
                right: 0,
                top: viewportH * _anchor,
                child: IgnorePointer(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.3),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (_isUserDragging &&
                _centerItemIndex >= 0 &&
                _centerItemIndex < _items.length) ...[
              Positioned(
                right: 4,
                top: viewportH * _anchor + 14,
                child: FloatingActionButton.small(
                  heroTag: 'amll_play_center',
                  elevation: 4,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _seekToCenter();
                  },
                  child: const Icon(Icons.play_arrow_rounded, size: 22),
                ),
              ),
              Positioned(
                left: 4,
                top: viewportH * _anchor + 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _centerTimeText(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'HarmonyOS Sans',
                      fontFeatures: [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
        return content;
      },
    );
  }

  String _fmt(int ms) {
    final s = (ms ~/ 1000);
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }
}

/// 歌词行组件：简洁行高亮 + 平滑颜色过渡（flutter_lyric 风格）。
/// 开启"歌词视图模糊"时按与当前行的距离模糊（AMLL 风格，越远越糊）。
class _AmllLyricRow extends StatefulWidget {
  final _LyricRow row;
  final bool isActive;
  final bool played;
  final int distance;
  final LyricSettings settings;

  const _AmllLyricRow({
    super.key,
    required this.row,
    required this.isActive,
    required this.played,
    required this.distance,
    required this.settings,
  });

  @override
  State<_AmllLyricRow> createState() => _AmllLyricRowState();
}

class _AmllLyricRowState extends State<_AmllLyricRow> {
  @override
  Widget build(BuildContext context) {
    final ls = widget.settings;

    // 简洁行状态（无缩放/逐字扫光）：
    // - 当前行：白色 + 加粗
    // - 已唱行：0.35 透明度；未唱行：0.5 透明度
    final double targetAlpha =
        widget.isActive ? 1.0 : (widget.played ? 0.35 : 0.5);

    // 按距离模糊（AMLL）：离当前行越远越糊，已唱行比未唱行更糊
    final double targetBlur = ls.blurEffect
        ? (widget.isActive
            ? 0.0
            : (widget.played
                ? (1.2 + widget.distance * 0.5).clamp(0.0, 3.5)
                : (0.6 + widget.distance * 0.25).clamp(0.0, 2.0)))
        : 0.0;

    final mainColor = Colors.white.withValues(alpha: targetAlpha);
    final secondaryColor =
        Colors.white.withValues(alpha: (targetAlpha * 0.6).clamp(0.0, 1.0));

    // Desktop needs much larger base font size than mobile
    final baseFontSize = ls.fontSize * 1.8;

    final mainStyle = TextStyle(
      fontSize: baseFontSize,
      fontWeight: widget.isActive ? FontWeight.w600 : ls.resolvedWeight,
      height: 1.5,
      color: mainColor,
      letterSpacing: widget.isActive ? 0.3 : 0.0,
    );

    final secondaryStyle = TextStyle(
      fontSize: baseFontSize * 0.5,
      fontWeight: ls.resolvedWeight,
      height: 1.5,
      color: secondaryColor,
    );

    final alignText = ls.centerAlign ? TextAlign.center : TextAlign.left;
    final crossAlign =
        ls.centerAlign ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final containerAlign =
        ls.centerAlign ? Alignment.center : Alignment.centerLeft;

    final Widget content = Align(
      alignment: containerAlign,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAlign,
        children: [
          AnimatedDefaultTextStyle(
            duration: _kSpringDuration,
            curve: _kSpringCurve,
            style: mainStyle,
            textAlign: alignText,
            child: Text(
              widget.row.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 翻译/罗马音行：开关切换时平滑淡入淡出 + 高度过渡
          _SecondaryLine(
            show: widget.row.translation != null,
            topPadding: 4,
            style: secondaryStyle,
            textAlign: alignText,
            text: widget.row.translation ?? '',
          ),
          _SecondaryLine(
            show: widget.row.romaji != null,
            topPadding: 1,
            style: secondaryStyle.copyWith(
                color: secondaryColor.withValues(
                    alpha: (targetAlpha * 0.45).clamp(0.0, 1.0))),
            textAlign: alignText,
            text: widget.row.romaji ?? '',
          ),
        ],
      ),
    );

    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: targetBlur, end: targetBlur),
        duration: _kSpringDuration,
        curve: _kSpringCurve,
        builder: (context, blur, child) {
          if (blur < 0.05) return child!;
          return ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: child,
          );
        },
        child: content,
      ),
    );
  }
}

/// 翻译/罗马音副行：开关切换时淡入淡出（AMLL 切换动画）。
///
/// 行高由外层固定 itemExtent 精确预留（见 [_DesktopAmllLyricsViewState._itemExtent]），
/// 因此这里不做 AnimatedSize 高度动画 —— 固定 itemExtent 的 ListView 中
/// 嵌套 AnimatedSize + AnimatedSwitcher 会在切换瞬间产生
/// "RenderBox was not laid out" 断言（布局/绘制中间态不一致）。
class _SecondaryLine extends StatelessWidget {
  final bool show;
  final double topPadding;
  final TextStyle style;
  final TextAlign textAlign;
  final String text;

  const _SecondaryLine({
    required this.show,
    required this.topPadding,
    required this.style,
    required this.textAlign,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.25),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: show
          ? Padding(
              key: const ValueKey('secondary_visible'),
              padding: EdgeInsets.only(top: topPadding),
              child: AnimatedDefaultTextStyle(
                duration: _kSpringDuration,
                curve: _kSpringCurve,
                style: style,
                textAlign: textAlign,
                child: Text(text),
              ),
            )
          : const SizedBox.shrink(key: ValueKey('secondary_hidden')),
    );
  }
}

/// 间奏等候动画：三圆点依次点亮 + 呼吸缩放 (AMLL interludeDots)。
/// 对齐方式与圆点大小跟随歌词设置（靠左/居中、字号比例）。
class _InterludeDotsRow extends StatefulWidget {
  final bool active;
  final bool isPlaying;
  final Alignment alignment;
  final double dotSize;

  const _InterludeDotsRow({
    required this.active,
    required this.isPlaying,
    this.alignment = Alignment.centerLeft,
    this.dotSize = 6.0,
  });

  @override
  State<_InterludeDotsRow> createState() => _InterludeDotsRowState();
}

class _InterludeDotsRowState extends State<_InterludeDotsRow>
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
  void didUpdateWidget(covariant _InterludeDotsRow oldWidget) {
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
    if (!widget.active) {
      // 占位：保持行高，圆点不可见
      return const SizedBox.shrink();
    }
    final dotSize = widget.dotSize;
    return Align(
      alignment: widget.alignment,
      child: Padding(
        // 靠左时贴近歌词文字起点
        padding: EdgeInsets.only(
            left: widget.alignment == Alignment.centerLeft ? 12.0 : 0),
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
                      margin: EdgeInsets.symmetric(horizontal: dotSize * 0.8),
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
      ),
    );
  }
}

class _LyricRow {
  final int startMs;
  final int endMs;
  final String text;
  final List<_LyricWord> words;
  final String? translation;
  final String? romaji;

  const _LyricRow({
    required this.startMs,
    required this.endMs,
    required this.text,
    required this.words,
    this.translation,
    this.romaji,
  });
}

class _LyricWord {
  final String text;
  final int startMs;
  final int endMs;

  const _LyricWord({
    required this.text,
    required this.startMs,
    required this.endMs,
  });
}

class _Interlude {
  final int startMs;
  final int endMs;
  final int anchorIndex;

  const _Interlude({
    required this.startMs,
    required this.endMs,
    required this.anchorIndex,
  });
}

class _Item {
  final _LyricRow? row;
  final _Interlude? interlude;

  const _Item._({this.row, this.interlude});

  factory _Item.row(_LyricRow row) => _Item._(row: row);

  factory _Item.interlude(_Interlude interlude) =>
      _Item._(interlude: interlude);

  bool get isInterlude => interlude != null;
}

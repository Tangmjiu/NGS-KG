// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_lyric/core/lyric_model.dart' show LyricLine;
import 'package:provider/provider.dart';
import 'package:wearable_rotary/wearable_rotary.dart';

import '../../providers/player_provider.dart';
import '../widgets/watch_player_primitives.dart';
import '../widgets/watch_scaffold.dart';

class WatchLyricsScreen extends StatefulWidget {
  const WatchLyricsScreen({super.key});

  @override
  State<WatchLyricsScreen> createState() => _WatchLyricsScreenState();
}

class _WatchLyricsScreenState extends State<WatchLyricsScreen>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController(keepScrollOffset: false);
  late final AnimationController _spring;
  late final StreamSubscription<RotaryEvent> _rotary;
  bool _following = true;
  bool _showTranslation = true;
  int _active = -1;
  double _viewport = 0;
  List<LyricLine>? _lines;
  Object? _measurementKey;
  List<double> _edges = const [0];

  @override
  void initState() {
    super.initState();
    _spring = AnimationController.unbounded(vsync: this)
      ..addListener(() => _jumpTo(_spring.value));
    _rotary = rotaryEvents.listen((event) {
      if (!mounted ||
          ModalRoute.of(context)?.isCurrent != true ||
          !_scroll.hasClients) {
        return;
      }
      _browse();
      final step = _scroll.position.viewportDimension * 0.3;
      _jumpTo(_scroll.offset +
          (event.direction == RotaryDirection.clockwise ? step : -step));
    });
  }

  @override
  void dispose() {
    _rotary.cancel();
    _spring.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _jumpTo(double offset) {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final target = offset.clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if (target != pos.pixels) _scroll.jumpTo(target.toDouble());
  }

  void _browse() {
    _spring.stop();
    if (_following) setState(() => _following = false);
  }

  void _follow() {
    setState(() => _following = true);
    _centerAfterLayout();
  }

  void _centerAfterLayout({bool immediately = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_following || !_scroll.hasClients || _active < 0 ||
          _active + 1 >= _edges.length) {
        return;
      }
      final height = _edges[_active + 1] - _edges[_active];
      // 两端各留半屏。超长行优先露出开头，再由用户向下阅读。
      final target = _edges[_active] + math.min(height, _viewport) / 2;
      final velocity = _spring.isAnimating ? _spring.velocity : 0.0;
      _spring.stop();
      if (immediately || MediaQuery.disableAnimationsOf(context)) {
        _jumpTo(target);
      } else {
        _spring.animateWith(SpringSimulation(
          watchPlayerSpring, _scroll.offset, target, velocity,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = context.select((PlayerProvider p) => p.lyricController);
    return WatchScaffold(
      showTime: false,
      body: WatchPlayerInsets(
        child: ValueListenableBuilder(
          valueListenable: player.lyricNotifier,
          builder: (context, model, _) {
            final lines = model?.lines ?? const <LyricLine>[];
            if (lines.isEmpty) {
              _spring.stop();
              _lines = null;
              return const Center(child: Text('暂无歌词'));
            }
            if (!identical(lines, _lines)) {
              _spring.stop();
              _lines = lines;
              _following = true;
              _measurementKey = null;
            }
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_following)
                      IconButton(
                        tooltip: '回到当前歌词',
                        icon: const Icon(Icons.my_location_rounded, size: 18),
                        onPressed: _follow,
                      ),
                    IconButton(
                      tooltip: _showTranslation ? '隐藏译文' : '显示译文',
                      isSelected: _showTranslation,
                      icon: const Icon(Icons.translate_rounded, size: 18),
                      selectedIcon: Icon(Icons.translate_rounded, size: 18,
                          color: Theme.of(context).colorScheme.primary),
                      onPressed: () => setState(() {
                        _showTranslation = !_showTranslation;
                      }),
                    ),
                  ],
                ),
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: player.activeIndexNotifiter,
                    builder: (context, index, _) => LayoutBuilder(
                      builder: (context, box) => _list(context, lines, index, box),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<LyricLine> lines, int active,
      BoxConstraints box) {
    final colors = Theme.of(context).colorScheme;
    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final primary = base.copyWith(fontSize: box.maxWidth < 140 ? 15 : 17,
        height: 1.3, fontWeight: FontWeight.w600);
    final secondary = base.copyWith(fontSize: 12, height: 1.3);
    final scaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    final direction = Directionality.of(context);
    final key = (box.maxWidth, scaler, locale, direction, primary, secondary,
        _showTranslation);
    final changed = _measurementKey != key;

    // 测量与渲染共用宽度、字体和缩放，焦点切换只变颜色，不改变行高。
    if (changed) {
      double measure(String text, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: direction, locale: locale, textScaler: scaler,
          textAlign: TextAlign.center,
        )..layout(maxWidth: box.maxWidth);
        final height = painter.height;
        painter.dispose();
        return height;
      }

      final edges = <double>[0];
      for (final line in lines) {
        var height = measure(line.text, primary) + 12;
        if (_showTranslation && line.translation?.isNotEmpty == true) {
          height += 3 + measure(line.translation!, secondary);
        }
        edges.add(edges.last + height);
      }
      _edges = edges;
      _measurementKey = key;
    }
    if (changed || _active != active || _viewport != box.maxHeight) {
      _active = active;
      _viewport = box.maxHeight;
      if (_following) _centerAfterLayout(immediately: changed);
    }

    Widget paragraph(String value, TextStyle style) => RichText(
      text: TextSpan(text: value, style: style),
      textDirection: direction, locale: locale, textScaler: scaler,
      textAlign: TextAlign.center,
    );
    return Listener(
      onPointerDown: (_) => _spring.stop(),
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) _browse();
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (event) {
          if (event is ScrollStartNotification && event.dragDetails != null ||
              event is ScrollUpdateNotification && event.dragDetails != null) {
            _browse();
          }
          return false;
        },
        child: ListView.builder(
          controller: _scroll,
          padding: EdgeInsets.symmetric(vertical: box.maxHeight / 2),
          itemCount: lines.length,
          itemExtentBuilder: (i, _) => i < lines.length ? _edges[i + 1] - _edges[i] : null,
          itemBuilder: (context, i) {
            final line = lines[i];
            final focused = i == active;
            return Semantics(
              selected: focused,
              button: true,
              child: InkWell(
                onTap: () {
                  final player = context.read<PlayerProvider>();
                  player.seek(line.start);
                  player.lyricController.setProgress(line.start);
                  _follow();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      paragraph(line.text, primary.copyWith(color: focused
                          ? colors.primary : colors.onSurfaceVariant)),
                      if (_showTranslation && line.translation?.isNotEmpty == true) ...[
                        const SizedBox(height: 3),
                        paragraph(line.translation!, secondary.copyWith(color: focused
                            ? colors.onSurface : colors.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

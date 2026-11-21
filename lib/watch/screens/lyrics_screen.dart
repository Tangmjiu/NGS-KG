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
  bool _hasTranslation = false;
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
      final step = _scroll.position.viewportDimension * .3;
      _jumpTo(
        _scroll.offset +
            (event.direction == RotaryDirection.clockwise ? step : -step),
      );
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
    final position = _scroll.position;
    final target = offset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target != position.pixels) _scroll.jumpTo(target);
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
      if (!mounted ||
          !_following ||
          !_scroll.hasClients ||
          _active < 0 ||
          _active + 1 >= _edges.length) {
        return;
      }
      final height = _edges[_active + 1] - _edges[_active];
      final target = _edges[_active] + math.min(height, _viewport) / 2;
      final velocity = _spring.isAnimating ? _spring.velocity : 0.0;
      _spring.stop();
      if (immediately || MediaQuery.disableAnimationsOf(context)) {
        _jumpTo(target);
      } else {
        _spring.animateWith(
          SpringSimulation(watchPlayerSpring, _scroll.offset, target, velocity),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.select((PlayerProvider p) => p.lyricController);
    final tone =
        context.select((PlayerProvider p) => p.palette?.dominant) ??
        const Color(0xff83a8a8);
    final pastel = Color.lerp(tone, Colors.white, .54)!;
    return WatchScaffold(
      showTime: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 1.12),
                radius: .65,
                colors: [Color.lerp(Colors.black, tone, .34)!, Colors.black],
              ),
            ),
          ),
          WatchPlayerInsets(
            child: ValueListenableBuilder(
              valueListenable: controller.lyricNotifier,
              builder: (context, model, _) {
                final lines = model?.lines ?? const <LyricLine>[];
                if (lines.isEmpty) {
                  _spring.stop();
                  _lines = null;
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_note_rounded, size: 18, color: pastel),
                        const SizedBox(height: 8),
                        const Text(
                          '暂无歌词',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  );
                }
                if (!identical(lines, _lines)) {
                  _spring.stop();
                  _lines = lines;
                  _following = true;
                  _measurementKey = null;
                  _hasTranslation = lines.any(
                    (line) => line.translation?.isNotEmpty == true,
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (rect) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x38ffffff),
                            Colors.white,
                            Colors.white,
                            Color(0x38ffffff),
                          ],
                          stops: [0, .30, .70, 1],
                        ).createShader(rect),
                        child: ValueListenableBuilder<int>(
                          valueListenable: controller.activeIndexNotifiter,
                          builder: (context, index, _) => LayoutBuilder(
                            builder: (context, box) =>
                                _list(context, lines, index, box, pastel),
                          ),
                        ),
                      ),
                    ),
                    if (!_following || _hasTranslation)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!_following)
                            SizedBox.square(
                              dimension: 48,
                              child: IconButton(
                                tooltip: '回到当前歌词',
                                icon: const Icon(
                                  Icons.my_location_rounded,
                                  size: 18,
                                ),
                                onPressed: _follow,
                              ),
                            ),
                          if (_hasTranslation)
                            SizedBox.square(
                              dimension: 48,
                              child: IconButton(
                                tooltip: _showTranslation ? '隐藏译文' : '显示译文',
                                icon: Icon(
                                  Icons.translate_rounded,
                                  size: 18,
                                  color: _showTranslation
                                      ? pastel
                                      : Colors.white60,
                                ),
                                onPressed: () => setState(
                                  () => _showTranslation = !_showTranslation,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(
    BuildContext context,
    List<LyricLine> lines,
    int active,
    BoxConstraints box,
    Color pastel,
  ) {
    const primary = TextStyle(
      fontFamily: 'serif',
      fontFamilyFallback: ['Roboto'],
      fontSize: 16,
      height: 1.22,
      fontWeight: FontWeight.w500,
    );
    const secondary = TextStyle(fontSize: 12, height: 1.22);
    final scaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    final direction = Directionality.of(context);
    final key = (box.maxWidth, scaler, locale, direction, _showTranslation);
    final changed = _measurementKey != key;
    if (changed) {
      double measure(String text, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: direction,
          locale: locale,
          textScaler: scaler,
          textAlign: TextAlign.center,
        )..layout(maxWidth: box.maxWidth);
        final height = painter.height;
        painter.dispose();
        return height;
      }

      final edges = <double>[0];
      for (final line in lines) {
        // Reserve the note and underline even when inactive, so changing the
        // highlighted line never shifts its neighbours or invalidates offsets.
        var height = measure(line.text, primary) + 25;
        if (_showTranslation && line.translation?.isNotEmpty == true) {
          height += 3 + measure(line.translation!, secondary);
        }
        edges.add(edges.last + math.max(48.0, height));
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
      textDirection: direction,
      locale: locale,
      textScaler: scaler,
      textAlign: TextAlign.center,
    );
    return Listener(
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
          itemExtentBuilder: (i, _) =>
              i < lines.length ? _edges[i + 1] - _edges[i] : null,
          itemBuilder: (context, i) {
            final line = lines[i];
            final focused = i == active;
            final ink = focused ? pastel : const Color(0xff9e9c9a);
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (focused)
                      Icon(Icons.music_note_rounded, size: 13, color: pastel),
                    if (focused) const SizedBox(height: 3),
                    paragraph(line.text, primary.copyWith(color: ink)),
                    if (_showTranslation &&
                        line.translation?.isNotEmpty == true) ...[
                      const SizedBox(height: 3),
                      paragraph(
                        line.translation!,
                        secondary.copyWith(color: ink),
                      ),
                    ],
                    if (focused) ...[
                      const SizedBox(height: 4),
                      Container(
                        height: 1,
                        width: 20,
                        color: pastel.withValues(alpha: .65),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

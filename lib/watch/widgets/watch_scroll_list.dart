// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wearable_rotary/wearable_rotary.dart';

import '../utils/watch_layout.dart';
import 'watch_player_primitives.dart' show watchPlayerSpring;

/// The scaffold supplies the horizontal safe area. Only end-of-list space
/// belongs here, so the last track can still reach the middle of the bezel.
class WatchScrollList extends StatefulWidget {
  const WatchScrollList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.itemExtent,
    this.autoScrollTo,
    this.autoScrollAlignment = 0.5,
    this.topPadding = 0,
    this.bottomPadding = 0,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ScrollController? controller;
  final double? itemExtent;
  final int? autoScrollTo;
  final double autoScrollAlignment;
  final double topPadding;
  final double bottomPadding;

  @override
  State<WatchScrollList> createState() => _WatchScrollListState();
}

class _WatchScrollListState extends State<WatchScrollList>
    with SingleTickerProviderStateMixin {
  late final _ownController = ScrollController(keepScrollOffset: false);
  ScrollController get _controller => widget.controller ?? _ownController;
  late final _motion = AnimationController.unbounded(vsync: this);
  StreamSubscription<RotaryEvent>? _rotary;
  DateTime? _lastInteraction;
  double? _destination;
  double _top = 0;

  bool get _ready =>
      mounted &&
      _controller.hasClients &&
      _controller.position.hasContentDimensions;

  @override
  void initState() {
    super.initState();
    _motion.addListener(_move);
    _rotary = rotaryEvents.listen(_turn);
    _positionAfterLayout(initial: true);
  }

  void _turn(RotaryEvent event) {
    if (!_ready ||
        ModalRoute.of(context)?.isCurrent != true ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    _lastInteraction = DateTime.now();
    final extent = widget.itemExtent ?? 52.0;
    final delta = (event.magnitude?.abs() ?? extent).clamp(1.0, extent * 2);
    final base = _motion.isAnimating ? _destination! : _controller.offset;
    _scroll(
      base + (event.direction == RotaryDirection.clockwise ? delta : -delta),
    );
  }

  void _move() {
    if (!_ready || ModalRoute.of(context)?.isCurrent != true) {
      _motion.stop();
      return;
    }
    final position = _controller.position;
    final offset = _motion.value.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (offset != position.pixels) _controller.jumpTo(offset);
  }

  void _scroll(double value, {bool immediate = false}) {
    final pos = _controller.position;
    final target = value.clamp(pos.minScrollExtent, pos.maxScrollExtent);
    final velocity = _motion.isAnimating ? _motion.velocity : 0.0;
    _motion.stop();
    _destination = target;
    if (immediate || MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpTo(target);
    } else {
      _motion.animateWith(
        ScrollSpringSimulation(watchPlayerSpring, pos.pixels, target, velocity),
      );
    }
  }

  void _positionAfterLayout({required bool initial}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index = widget.autoScrollTo;
      final extent = widget.itemExtent;
      if (!_ready ||
          index == null ||
          extent == null ||
          index < 0 ||
          index >= widget.itemCount ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final interaction = _lastInteraction;
      if (!initial &&
          interaction != null &&
          DateTime.now().difference(interaction) < const Duration(seconds: 3)) {
        return;
      }
      final room = _controller.position.viewportDimension - extent;
      _scroll(
        _top + index * extent - room * widget.autoScrollAlignment,
        immediate: initial,
      );
    });
  }

  @override
  void didUpdateWidget(WatchScrollList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _motion.stop();
    if (oldWidget.autoScrollTo != widget.autoScrollTo ||
        oldWidget.controller != widget.controller ||
        oldWidget.itemCount == 0 && widget.itemCount > 0) {
      _positionAfterLayout(initial: oldWidget.autoScrollTo == null);
    }
  }

  @override
  void dispose() {
    _rotary?.cancel();
    _motion.dispose();
    _ownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final round = WatchLayout.of(context).isRound;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = widget.itemExtent;
        final height = constraints.maxHeight;
        final room = math.max(0.0, height - (extent ?? height));
        _top =
            widget.topPadding +
            (widget.autoScrollTo == null
                ? 0
                : room * widget.autoScrollAlignment);
        final bottom = math.max(
          widget.bottomPadding,
          room * (1 - widget.autoScrollAlignment),
        );
        return NotificationListener<ScrollStartNotification>(
          onNotification: (notification) {
            if (notification.dragDetails != null) {
              _motion.stop();
              _lastInteraction = DateTime.now();
            }
            return false;
          },
          child: ListView.builder(
            controller: _controller,
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(),
            clipBehavior: Clip.hardEdge,
            itemExtent: extent,
            padding: EdgeInsets.only(top: _top, bottom: bottom),
            itemCount: widget.itemCount,
            itemBuilder: (context, index) {
              final item = widget.itemBuilder(context, index);
              if (!round || reduceMotion || extent == null || height <= 0) {
                return item;
              }
              return AnimatedBuilder(
                animation: _controller,
                child: item,
                builder: (_, child) {
                  final offset = _controller.hasClients
                      ? _controller.offset
                      : 0.0;
                  final y = _top + (index + 0.5) * extent - offset;
                  final distance = ((y / height - 0.5).abs() * 2).clamp(
                    0.0,
                    1.0,
                  );
                  final edge = distance * distance;
                  return Opacity(
                    opacity: 1 - 0.23 * edge,
                    child: Transform.scale(
                      scale: 1 - 0.12 * edge,
                      child: child,
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class WatchCatalogTitle extends StatelessWidget {
  const WatchCatalogTitle(this.title, {super.key, this.caption});
  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (caption != null)
            Text(
              caption!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Keeps empty, loading and retry states scrollable on a short watch or above the keyboard.
class WatchCatalogNotice extends StatelessWidget {
  const WatchCatalogNotice(
    this.text, {
    super.key,
    this.icon,
    this.action,
    this.busy = false,
  });
  final String text;
  final IconData? icon;
  final Widget? action;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (_, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else if (icon != null)
                Icon(icon, color: theme.colorScheme.primary, size: 26),
              const SizedBox(height: 4),
              Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              if (action != null) action!,
            ],
          ),
        ),
      ),
    );
  }
}

// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../utils/watch_layout.dart';

/// Wear motion uses a dimensionless damping ratio. Flutter converts it to c.
final watchPlayerSpring = SpringDescription.withDampingRatio(
  mass: 1, stiffness: 380, ratio: 0.8,
);

class WatchPlayerInsets extends StatelessWidget {
  const WatchPlayerInsets({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    return SafeArea(
      minimum: EdgeInsets.all(layout.isRound ? layout.diameter * 0.12 : 8),
      child: child,
    );
  }
}

/// One-shot physical reveal; key by track or panel, never by playback position.
class WatchSpringReveal extends StatefulWidget {
  const WatchSpringReveal({super.key, required this.child});
  final Widget child;

  @override
  State<WatchSpringReveal> createState() => _WatchSpringRevealState();
}

class _WatchSpringRevealState extends State<WatchSpringReveal>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController.unbounded(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      _motion.animateWith(SpringSimulation(watchPlayerSpring, 0, 1, 0));
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    child: widget.child,
    builder: (_, child) => Transform.translate(
      offset: Offset(0, (1 - _motion.value) * 5),
      child: Opacity(opacity: _motion.value.clamp(0.0, 1.0), child: child),
    ),
  );
}

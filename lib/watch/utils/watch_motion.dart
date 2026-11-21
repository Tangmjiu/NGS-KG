// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';

class _WatchSpringCurve extends Curve {
  const _WatchSpringCurve();
  static final _spring = SpringSimulation(
    SpringDescription.withDampingRatio(mass: 1, stiffness: 380, ratio: .8),
    0,
    1,
    0,
  );
  @override
  double transformInternal(double t) => _spring.x(t * .45).clamp(0.0, 1.0);
}

class WatchMotion {
  WatchMotion._();

  static const Duration durShort2 = Duration(milliseconds: 100);
  static const Duration durShort3 = Duration(milliseconds: 150);
  static const Duration durShort4 = Duration(milliseconds: 200);
  static const Duration durMedium1 = Duration(milliseconds: 250);
  static const Duration durMedium2 = Duration(milliseconds: 300);
  static const Duration durMedium4 = Duration(milliseconds: 400);
  static const Duration durLong1 = Duration(milliseconds: 450);

  static const Curve curveStandard = _WatchSpringCurve();
  static const Curve curveEmphasized = curveStandard;
  static const Curve curveDecelerate = curveStandard;
  static const Curve curveAccelerate = curveStandard;

  static void tap() => HapticFeedback.selectionClick();
  static void confirm() => HapticFeedback.lightImpact();
  static void heavy() => HapticFeedback.mediumImpact();
}

// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';

class WatchMotion {
  WatchMotion._();

  static const Duration durShort2 = Duration(milliseconds: 100);
  static const Duration durShort3 = Duration(milliseconds: 150);
  static const Duration durShort4 = Duration(milliseconds: 200);
  static const Duration durMedium1 = Duration(milliseconds: 250);
  static const Duration durMedium2 = Duration(milliseconds: 300);
  static const Duration durMedium4 = Duration(milliseconds: 400);
  static const Duration durLong1 = Duration(milliseconds: 450);

  static const Curve curveStandard = Curves.easeInOutCubic;
  static const Curve curveEmphasized = Curves.easeOutBack;
  static const Curve curveDecelerate = Curves.easeOutCubic;
  static const Curve curveAccelerate = Curves.easeInCubic;

  static void tap() => HapticFeedback.selectionClick();
  static void confirm() => HapticFeedback.lightImpact();
  static void heavy() => HapticFeedback.mediumImpact();
}

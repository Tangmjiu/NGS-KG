// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

abstract final class AppChrome {
  static const navigationExtent = 80.0;
  static const railExtent = 96.0;

  static bool usesRail(double width) => width >= AppBreakpoint.compact;

  static double miniPlayerExtent(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return (33 + textScaler.scale(14) * 1.2 + textScaler.scale(12) * 1.2)
        .ceilToDouble()
        .clamp(76.0, double.infinity);
  }
}

/// MD3 形状 token — 统一 BorderRadius，禁止 magic number
abstract final class AppShape {
  AppShape._();

  /// extra-small: 4dp — Chips, snackbars
  static const BorderRadius xs = BorderRadius.all(Radius.circular(4));

  /// small: 8dp — Text fields, menus, buttons
  static const BorderRadius sm = BorderRadius.all(Radius.circular(8));

  /// medium: 12dp — Cards, dialogs
  static const BorderRadius md = BorderRadius.all(Radius.circular(12));

  /// large: 16dp — FABs, navigation drawer
  static const BorderRadius lg = BorderRadius.all(Radius.circular(16));

  /// extra-large: 28dp — Bottom sheets, dialogs
  static const BorderRadius xl = BorderRadius.all(Radius.circular(28));

  /// full: pill shape — Buttons, chips, badges
  static const BorderRadius full = BorderRadius.all(Radius.circular(9999));
}

/// MD3 响应式断点
abstract final class AppBreakpoint {
  AppBreakpoint._();

  static const double compact = 600;
  static const double medium = 840;
  static const double expanded = 1200;

  static bool isCompact(double width) => width < compact;
  static bool isMedium(double width) => width >= compact && width < medium;
  static bool isExpanded(double width) => width >= medium;

  static int columnCount(double width) =>
      width >= expanded ? 3 : (width >= compact ? 2 : 1);
}

// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

/// 共享动效配置与主题一起变化；空间变化可回弹，透明度等效果保持单调。
@immutable
class AppMotionTheme extends ThemeExtension<AppMotionTheme> {
  final double durationScale;
  final Curve effectsCurve;

  const AppMotionTheme({
    this.durationScale = 1,
    this.effectsCurve = Curves.easeInOutCubicEmphasized,
  });

  static AppMotionTheme of(BuildContext context) =>
      Theme.of(context).extension<AppMotionTheme>() ?? const AppMotionTheme();

  Duration scale(Duration value) =>
      Duration(microseconds: (value.inMicroseconds * durationScale).round());

  SpringDescription get spatialSpring => SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: 800 / (durationScale * durationScale),
        ratio: 0.6,
      );

  @override
  AppMotionTheme copyWith({double? durationScale, Curve? effectsCurve}) =>
      AppMotionTheme(
        durationScale: durationScale ?? this.durationScale,
        effectsCurve: effectsCurve ?? this.effectsCurve,
      );

  @override
  AppMotionTheme lerp(covariant AppMotionTheme? other, double t) {
    if (other == null) return this;
    return AppMotionTheme(
      durationScale: durationScale + (other.durationScale - durationScale) * t,
      effectsCurve: t < 0.5 ? effectsCurve : other.effectsCurve,
    );
  }
}

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Returns true when running on a desktop-class platform (Windows, macOS, Linux).
bool get _isDesktopPlatform =>
    !kIsWeb &&
    (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

/// Responsive breakpoints for mobile / tablet / desktop.
class Breakpoint {
  static const double mobile = 600;
  static const double tablet = 900;

  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < tablet;
  static bool isDesktop(double width) => width >= tablet;
}

/// Screen-size-aware helpers, driven by [MediaQuery].
///
/// On desktop platforms (Windows / macOS / Linux) the helpers always report
/// [isDesktop] == true regardless of window width, so dragging the window
/// narrower will NOT switch to the mobile layout.
class Responsive {
  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static bool isMobile(BuildContext context) {
    if (_isDesktopPlatform) return false;
    return Breakpoint.isMobile(MediaQuery.of(context).size.width);
  }

  static bool isTablet(BuildContext context) {
    if (_isDesktopPlatform) return false;
    return Breakpoint.isTablet(MediaQuery.of(context).size.width);
  }

  static bool isDesktop(BuildContext context) {
    if (_isDesktopPlatform) return true;
    return Breakpoint.isDesktop(MediaQuery.of(context).size.width);
  }

  /// Returns a value based on the current screen size and platform.
  ///
  /// On desktop platforms [desktop] is always returned.
  static T select<T>(BuildContext context, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (_isDesktopPlatform) return desktop;
    final w = MediaQuery.of(context).size.width;
    if (w >= Breakpoint.tablet) return desktop;
    if (w >= Breakpoint.mobile) return tablet ?? desktop;
    return mobile;
  }
}

/// Reactive layout builder that rebuilds when the screen crosses breakpoints.
///
/// On desktop platforms the [desktop] branch is always rendered so that
/// resizing the window never switches to the mobile layout.
///
/// ```
/// ResponsiveLayoutBuilder(
///   mobile: (context) => MobileHome(),
///   tablet: (context) => TabletHome(),
///   desktop: (context) => DesktopHome(),
/// )
/// ```
class ResponsiveLayoutBuilder extends StatelessWidget {
  final Widget Function(BuildContext) mobile;
  final Widget Function(BuildContext)? tablet;
  final Widget Function(BuildContext) desktop;

  const ResponsiveLayoutBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    // Desktop platform → always desktop layout
    if (_isDesktopPlatform) return desktop(context);

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      if (w >= Breakpoint.tablet) return desktop(context);
      if (w >= Breakpoint.mobile) return (tablet ?? desktop)(context);
      return mobile(context);
    });
  }
}

/// Constrains content to a comfortable reading width on large screens.
///
/// On desktop the content is centered in a [maxWidth] box (default 900);
/// on mobile/tablet it fills the available space.
class AdaptiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const AdaptiveContent({
    super.key,
    required this.child,
    this.maxWidth = 900,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      mobile: (_) => child,
      tablet: (_) => child,
      desktop: (_) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// Padding that scales with screen size.
EdgeInsetsGeometry adaptivePadding(BuildContext context,
    {double mobile = 16, double tablet = 24, double desktop = 32}) {
  return EdgeInsets.all(
    Responsive.select(context, mobile: mobile, tablet: tablet, desktop: desktop),
  );
}

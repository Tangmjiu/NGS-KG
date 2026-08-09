/// Animated theme container for app-wide palette management.
library;

import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

/// Provides animated theme transitions throughout the widget tree.
///
/// Wrap your MaterialApp with [PaletteScope] to enable smooth color
/// transitions when the palette changes.
///
/// Example:
/// ```dart
/// PaletteScope(
///   seed: ThemeColors.fallback(),
///   brightness: Brightness.dark,
///   child: MaterialApp(
///     theme: PaletteScope.of(context).theme,
///     home: MyHomePage(),
///   ),
/// )
/// ```
class PaletteScope extends StatefulWidget {
  /// Initial theme colors.
  final ThemeColors seed;

  /// Child widget (typically MaterialApp).
  final Widget child;

  /// Theme brightness.
  final Brightness brightness;

  const PaletteScope({
    super.key,
    required this.seed,
    required this.child,
    this.brightness = Brightness.light,
  });

  /// Get the [PaletteController] from context.
  ///
  /// Throws if [PaletteScope] is not found in tree.
  static PaletteController of(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<_PaletteInherited>();
    assert(
      inherited != null,
      'PaletteScope.of() called with no PaletteScope in context',
    );
    return inherited!.controller;
  }

  /// Get the [PaletteController] from context, or null if not found.
  static PaletteController? maybeOf(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<_PaletteInherited>();
    return inherited?.controller;
  }

  @override
  State<PaletteScope> createState() => _PaletteScopeState();
}

class _PaletteScopeState extends State<PaletteScope>
    with SingleTickerProviderStateMixin {
  late PaletteController controller;

  @override
  void initState() {
    super.initState();
    controller = PaletteController(
      widget.seed,
      vsync: this,
      brightness: widget.brightness,
    );
  }

  @override
  void didUpdateWidget(covariant PaletteScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brightness != widget.brightness) {
      controller = PaletteController(
        controller.current,
        vsync: this,
        brightness: widget.brightness,
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller._anim,
      builder: (_, child) {
        return _PaletteInherited(
          controller: controller,
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}

class _PaletteInherited extends InheritedWidget {
  final PaletteController controller;

  const _PaletteInherited({
    required this.controller,
    required super.child,
  });

  @override
  bool updateShouldNotify(covariant _PaletteInherited oldWidget) =>
      controller != oldWidget.controller;
}

/// Controls theme color animations within a [PaletteScope].
class PaletteController extends ChangeNotifier {
  late ThemeColors _current;
  late ThemeColors _target;

  /// Theme brightness.
  final Brightness brightness;

  final AnimationController _anim;

  PaletteController(
    ThemeColors seed, {
    required TickerProvider vsync,
    required this.brightness,
  })  : _current = seed,
        _target = seed,
        _anim = AnimationController(
          vsync: vsync,
          duration: const Duration(milliseconds: 1),
        )..value = 1.0;

  /// Get the current Material theme.
  ThemeData get theme => lerpThemeColors(_current, _target, _anim.value)
      .toThemeData(brightness: brightness);

  /// Get the current theme colors.
  ThemeColors get current => _target;

  /// Animate to new theme colors.
  ///
  /// Example:
  /// ```dart
  /// final controller = PaletteScope.of(context);
  /// controller.animateTo(
  ///   newColors,
  ///   duration: Duration(milliseconds: 800),
  ///   curve: Curves.easeOutCubic,
  /// );
  /// ```
  void animateTo(
    ThemeColors colors, {
    Duration duration = const Duration(milliseconds: 420),
    Curve curve = Curves.easeOutCubic,
  }) {
    _current = lerpThemeColors(
      _current,
      _target,
      _anim.value,
    ); // freeze current from ongoing anim
    _target = colors;
    _anim.stop();
    _anim.duration = duration;
    _anim.forward(from: 0.0);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }
}

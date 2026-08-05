/// Full-screen scaffold with adaptive gradient background.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../models.dart';
import '../palette_scope.dart';
import 'widget_helpers.dart';

/// Full-screen scaffold that paints an adaptive gradient background.
///
/// **DEPRECATED**: Use [FluidBackground] instead for immersive animated backgrounds.
///
/// This widget is maintained for backward compatibility but will be removed in v4.0.0.
/// Migrate to FluidBackground for better performance and visual quality.
///
/// Example:
/// ```dart
/// AdaptiveGradientScaffold.network(
///   'https://example.com/hero.jpg',
///   appBar: AppBar(title: Text('Details')),
///   body: YourContent(),
///   syncWithPaletteScope: true, // Drives app-wide theme
/// )
/// ```
@Deprecated('Use FluidBackground instead. Will be removed in v4.0.0')
class AdaptiveGradientScaffold extends StatefulWidget {
  final ImageProvider imageProvider;
  final AdaptiveOverlayStyle gradientStyle;
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final FloatingActionButtonAnimator? floatingActionButtonAnimator;
  final List<Widget>? persistentFooterButtons;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Widget? drawer;
  final Widget? endDrawer;
  final bool resizeToAvoidBottomInset;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final ExtractionConfig config;
  final Duration animationDuration;
  final Curve animationCurve;
  final ThemeColors fallbackColors;
  final ValueChanged<ThemeColors>? onColorsReady;
  final bool syncWithPaletteScope;

  const AdaptiveGradientScaffold({
    super.key,
    required this.imageProvider,
    this.gradientStyle = const AdaptiveOverlayStyle(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0.0, 0.45, 1.0],
      opacities: [0.95, 0.55, 0.1],
      tone: AdaptiveOverlayTone.surface,
    ),
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.floatingActionButtonAnimator,
    this.persistentFooterButtons,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.drawer,
    this.endDrawer,
    this.resizeToAvoidBottomInset = true,
    this.extendBody = true,
    this.extendBodyBehindAppBar = true,
    this.config = const ExtractionConfig(),
    this.animationDuration = const Duration(milliseconds: 600),
    this.animationCurve = Curves.easeOutCubic,
    this.fallbackColors = const ThemeColors.fallback(),
    this.onColorsReady,
    this.syncWithPaletteScope = true,
  });

  /// Create scaffold with network image.
  factory AdaptiveGradientScaffold.network(
    String imageUrl, {
    Key? key,
    AdaptiveOverlayStyle gradientStyle = const AdaptiveOverlayStyle(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0.0, 0.45, 1.0],
      opacities: [0.95, 0.55, 0.1],
      tone: AdaptiveOverlayTone.surface,
    ),
    PreferredSizeWidget? appBar,
    Widget? body,
    Widget? floatingActionButton,
    FloatingActionButtonLocation? floatingActionButtonLocation,
    FloatingActionButtonAnimator? floatingActionButtonAnimator,
    List<Widget>? persistentFooterButtons,
    Widget? bottomNavigationBar,
    Widget? bottomSheet,
    Widget? drawer,
    Widget? endDrawer,
    bool resizeToAvoidBottomInset = true,
    bool extendBody = true,
    bool extendBodyBehindAppBar = true,
    ExtractionConfig config = const ExtractionConfig(),
    Duration animationDuration = const Duration(milliseconds: 600),
    Curve animationCurve = Curves.easeOutCubic,
    ThemeColors fallbackColors = const ThemeColors.fallback(),
    ValueChanged<ThemeColors>? onColorsReady,
    bool syncWithPaletteScope = true,
  }) {
    return AdaptiveGradientScaffold(
      key: key,
      imageProvider: CachedNetworkImageProvider(imageUrl),
      gradientStyle: gradientStyle,
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      floatingActionButtonAnimator: floatingActionButtonAnimator,
      persistentFooterButtons: persistentFooterButtons,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
      drawer: drawer,
      endDrawer: endDrawer,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      config: config,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
      fallbackColors: fallbackColors,
      onColorsReady: onColorsReady,
      syncWithPaletteScope: syncWithPaletteScope,
    );
  }

  @override
  State<AdaptiveGradientScaffold> createState() =>
      _AdaptiveGradientScaffoldState();
}

class _AdaptiveGradientScaffoldState extends State<AdaptiveGradientScaffold> {
  ThemeColors? _colors;

  @override
  void initState() {
    super.initState();
    _extractColors();
  }

  @override
  void didUpdateWidget(covariant AdaptiveGradientScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider ||
        oldWidget.config.targetBrightness != widget.config.targetBrightness) {
      _extractColors();
    }
  }

  Future<void> _extractColors() async {
    final colors = await extractColorsFromProvider(
      widget.imageProvider,
      widget.config,
      widget.fallbackColors,
    );
    if (!mounted) return;
    setState(() => _colors = colors);
    widget.onColorsReady?.call(colors);
    if (widget.syncWithPaletteScope) {
      final controller = PaletteScope.maybeOf(context);
      controller?.animateTo(
        colors,
        duration: widget.animationDuration,
        curve: widget.animationCurve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradient = (_colors ?? widget.fallbackColors)
        .overlayGradient(style: widget.gradientStyle);

    return AnimatedContainer(
      duration: widget.animationDuration,
      curve: widget.animationCurve,
      decoration: BoxDecoration(gradient: gradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: widget.extendBody,
        extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
        resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
        appBar: widget.appBar,
        body: widget.body,
        floatingActionButton: widget.floatingActionButton,
        floatingActionButtonLocation: widget.floatingActionButtonLocation,
        floatingActionButtonAnimator: widget.floatingActionButtonAnimator,
        persistentFooterButtons: widget.persistentFooterButtons,
        bottomNavigationBar: widget.bottomNavigationBar,
        bottomSheet: widget.bottomSheet,
        drawer: widget.drawer,
        endDrawer: widget.endDrawer,
      ),
    );
  }
}

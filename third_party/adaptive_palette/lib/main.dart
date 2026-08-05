import 'package:adaptive_palette/adaptive_palette.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

void main() => runApp(
      const PaletteScope(
        seed: ThemeColors.fallback(),
        brightness: Brightness.dark,
        child: MyApp(),
      ),
    );

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: PaletteScope.of(context).theme,
        home: const AdaptiveBackgroundDemo(),
      );
}

/// Ultra-optimized Luma-style adaptive background - ONE FEATURE ONLY
class AdaptiveBackgroundDemo extends StatefulWidget {
  const AdaptiveBackgroundDemo({super.key});

  @override
  State<AdaptiveBackgroundDemo> createState() => _AdaptiveBackgroundDemoState();
}

class _AdaptiveBackgroundDemoState extends State<AdaptiveBackgroundDemo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  ThemeColors? _extractedColors;
  bool _isLoading = true;

  // Use a single beautiful image - no network calls, no heavy operations
  static const String demoImage = 'https://picsum.photos/800/600';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _extractPalette();
  }

  Future<void> _extractPalette() async {
    // Extract colors with optimized settings
    final colors = await AdaptivePalette.fromImage(
      const NetworkImage(demoImage),
      targetBrightness: Brightness.dark,
      resize: 64, // Smaller = faster
      quantizeColors: 32, // Fewer colors = faster
      minContrast: 4.5,
    );

    if (!mounted) return;

    setState(() {
      _extractedColors = colors;
      _isLoading = false;
    });

    // Animate theme
    PaletteScope.of(context).animateTo(
      colors,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    );

    // Start fade animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Single blurred background - optimized
          FadeTransition(
            opacity: _fadeAnimation,
            child: RepaintBoundary(
              child: Transform.scale(
                scale: 1.2,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: 80,
                    sigmaY: 80,
                    tileMode: TileMode.decal,
                  ),
                  child: Image.network(
                    demoImage,
                    fit: BoxFit.cover,
                    frameBuilder:
                        (context, child, frame, wasSynchronouslyLoaded) {
                      if (wasSynchronouslyLoaded) return child;
                      return frame != null
                          ? child
                          : Container(color: Colors.black);
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        Container(color: Colors.black),
                  ),
                ),
              ),
            ),
          ),

          // Subtle color overlay
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.surface.withOpacity(0.1),
                    scheme.surface.withOpacity(0.3),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                // Sharp image card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Card(
                      elevation: 24,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Image.network(
                            demoImage,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(color: const Color(0xFF1A1A1A)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Title
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Text(
                    'Adaptive Palette',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                const Spacer(),

                // Color swatches
                if (!_isLoading && _extractedColors != null)
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ColorSwatch(
                            color: _extractedColors!.primary,
                            label: 'Primary',
                          ),
                          const SizedBox(width: 12),
                          _ColorSwatch(
                            color: _extractedColors!.secondary,
                            label: 'Secondary',
                          ),
                          const SizedBox(width: 12),
                          _ColorSwatch(
                            color: _extractedColors!.surface,
                            label: 'Surface',
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 48),
              ],
            ),
          ),

          // Loading indicator
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withOpacity(0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final String label;

  const _ColorSwatch({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

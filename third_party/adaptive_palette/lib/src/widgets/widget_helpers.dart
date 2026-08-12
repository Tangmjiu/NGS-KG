/// Shared helpers for adaptive widgets.
library;

import 'package:flutter/widgets.dart';

import '../../adaptive_palette.dart' show AdaptivePalette;
import '../config.dart';
import '../models.dart';

/// Extract colors from an image provider safely with fallback.
///
/// This is used internally by all adaptive widgets to handle
/// extraction errors gracefully.
Future<ThemeColors> extractColorsFromProvider(
  ImageProvider provider,
  ExtractionConfig config,
  ThemeColors fallback,
) async {
  try {
    return await AdaptivePalette.fromImage(provider, config: config);
  } catch (error, stack) {
    config.onError?.call(error, stack);
    return fallback;
  }
}

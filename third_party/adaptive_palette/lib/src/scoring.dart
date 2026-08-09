/// Intelligent color scoring that adapts to image characteristics.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:material_color_utilities/material_color_utilities.dart' as mcu;

import 'config.dart';
import 'models.dart';

/// Analyze image characteristics from color swatches.
ImageCharacteristics analyzeImageCharacteristics(List<Swatch> swatches) {
  if (swatches.isEmpty) {
    return const ImageCharacteristics(
      avgSaturation: 0,
      avgChroma: 0,
      isColorful: false,
      isMonochromatic: true,
      hasFewColors: true,
    );
  }

  final totalPixels = swatches.fold<int>(0, (sum, s) => sum + s.population);
  if (totalPixels == 0) {
    return const ImageCharacteristics(
      avgSaturation: 0,
      avgChroma: 0,
      isColorful: false,
      isMonochromatic: true,
      hasFewColors: true,
    );
  }

  double avgSaturation = 0.0;
  double avgChroma = 0.0;

  for (final s in swatches) {
    final c = s.color;
    final r = (0x00ff0000 & c.value) >> 16;
    final g = (0x0000ff00 & c.value) >> 8;
    final b = (0x000000ff & c.value) >> 0;

    final maxCh = math.max(r, math.max(g, b)) / 255.0;
    final minCh = math.min(r, math.min(g, b)) / 255.0;
    final sat = maxCh == 0 ? 0.0 : (maxCh - minCh) / maxCh;

    final cam = mcu.Cam16.fromInt(c.value);
    final weight = s.population / totalPixels;

    avgSaturation += sat * weight;
    avgChroma += cam.chroma * weight;
  }

  final isColorful = avgSaturation > 0.3 || avgChroma > 25;
  final isMonochromatic = avgSaturation < 0.15 && avgChroma < 15;
  final hasFewColors = swatches.length < 8;

  return ImageCharacteristics(
    avgSaturation: avgSaturation,
    avgChroma: avgChroma,
    isColorful: isColorful,
    isMonochromatic: isMonochromatic,
    hasFewColors: hasFewColors,
  );
}

/// Get adaptive thresholds based on image characteristics.
({
  double satThreshold,
  double chromaThreshold,
  double toneMin,
  double toneMax,
}) getAdaptiveThresholds(ImageCharacteristics characteristics) {
  final satThreshold = characteristics.isMonochromatic
      ? 0.08
      : (characteristics.isColorful ? 0.18 : 0.12);
  final chromaThreshold = characteristics.isMonochromatic
      ? 5.0
      : (characteristics.isColorful ? 12.0 : 8.0);
  final toneMin = characteristics.isMonochromatic ? 12.0 : 15.0;
  final toneMax = characteristics.isMonochromatic ? 88.0 : 85.0;

  return (
    satThreshold: satThreshold,
    chromaThreshold: chromaThreshold,
    toneMin: toneMin,
    toneMax: toneMax,
  );
}

/// Get adaptive scoring weights based on image characteristics.
({
  double popWeight,
  double chromaWeight,
  double toneWeight,
}) getAdaptiveWeights(ImageCharacteristics characteristics) {
  final popWeight = characteristics.isColorful
      ? 0.55
      : (characteristics.isMonochromatic ? 0.65 : 0.60);
  final chromaWeight = characteristics.isColorful
      ? 0.30
      : (characteristics.isMonochromatic ? 0.15 : 0.25);
  final toneWeight = 1.0 - popWeight - chromaWeight;

  return (
    popWeight: popWeight,
    chromaWeight: chromaWeight,
    toneWeight: toneWeight,
  );
}

/// Score a single color swatch.
double scoreColor(
  Swatch swatch,
  ImageCharacteristics characteristics,
  int maxPopulation, {
  List<ScoredSwatch> topColors = const [],
  double diversityWeight = 1.1,
}) {
  final c = swatch.color;
  final r = (0x00ff0000 & c.value) >> 16;
  final g = (0x0000ff00 & c.value) >> 8;
  final b = (0x000000ff & c.value) >> 0;

  // Use CAM16 for perceptually accurate color analysis
  final cam = mcu.Cam16.fromInt(c.value);
  final chroma = cam.chroma;
  final tone = mcu.Hct.fromInt(c.value).tone;

  // HSV saturation
  final maxCh = math.max(r, math.max(g, b)) / 255.0;
  final minCh = math.min(r, math.min(g, b)) / 255.0;
  final saturation = maxCh == 0 ? 0.0 : (maxCh - minCh) / maxCh;

  final thresholds = getAdaptiveThresholds(characteristics);
  final weights = getAdaptiveWeights(characteristics);

  // Population score (normalized 0-1)
  final popScore = swatch.population / maxPopulation;

  // Chroma score (0-1) - Adaptive scaling
  final chromaScale = characteristics.isColorful ? 70.0 : 50.0;
  final chromaScore = math.min(1.0, chroma / chromaScale);

  // ADAPTIVE FILTERING

  // Filter near-black
  if (tone < (characteristics.hasFewColors ? 8.0 : thresholds.toneMin)) {
    return 0.05 * popScore;
  }

  // Filter near-white
  if (tone > thresholds.toneMax) {
    return 0.05 * popScore;
  }

  // Filter low saturation
  if (saturation < thresholds.satThreshold) {
    final penalty = characteristics.isMonochromatic ? 0.50 : 0.20;
    return penalty * popScore;
  }

  // Filter low chroma
  if (chroma < thresholds.chromaThreshold) {
    final penalty = characteristics.isMonochromatic ? 0.60 : 0.25;
    return penalty * popScore;
  }

  // INTELLIGENT SCORING

  // Tone preference score
  final toneScore = tone >= thresholds.toneMin && tone <= thresholds.toneMax
      ? (tone >= 30 && tone <= 70 ? 1.0 : 0.85)
      : 0.4;

  // Base score with adaptive weights
  final baseScore = (weights.popWeight * popScore) +
      (weights.chromaWeight * chromaScore) +
      (weights.toneWeight * toneScore);

  // CONDITIONAL BOOSTS

  // Chroma boost
  var chromaBoost = 1.0;
  if (characteristics.isColorful && chroma > 35) {
    chromaBoost = 1.0 + math.min(0.5, (chroma - 35) / 70.0);
  } else if (!characteristics.isMonochromatic && chroma > 25) {
    chromaBoost = 1.0 + math.min(0.3, (chroma - 25) / 80.0);
  }

  // Mid-tone boost
  final midToneBoost = (tone >= 30 && tone <= 70) ? 1.2 : 1.0;

  // Saturation boost
  var satBoost = 1.0;
  if (saturation > 0.4) {
    final boostStrength = characteristics.isColorful ? 0.6 : 0.3;
    satBoost = 1.0 + ((saturation - 0.4) * boostStrength);
  }

  // Diversity boost
  var diversityBoost = 1.0;
  if (topColors.isNotEmpty && topColors.length < 3) {
    final topColor = topColors.first.swatch.color;
    final colorDiff = computeColorDistance(c, topColor);
    if (colorDiff > 40) {
      diversityBoost = diversityWeight;
    }
  }

  // Final score
  return baseScore * chromaBoost * midToneBoost * satBoost * diversityBoost;
}

/// Score and rank all swatches.
///
/// Returns sorted list of scored swatches (highest score first).
List<ScoredSwatch> scoreSwatches(
  List<Swatch> swatches,
  ExtractionConfig config,
) {
  if (swatches.isEmpty) return [];

  final characteristics = analyzeImageCharacteristics(swatches);
  final maxPop = swatches.fold<int>(0, (max, s) => math.max(max, s.population));
  if (maxPop == 0) return [];

  final List<ScoredSwatch> out = [];

  for (final swatch in swatches) {
    final score = scoreColor(
      swatch,
      characteristics,
      maxPop,
      topColors: out,
      diversityWeight: config.diversityWeight,
    );
    out.add(ScoredSwatch(swatch, score));
  }

  // Sort by score (highest first)
  out.sort((a, b) => b.score.compareTo(a.score));

  return out;
}

/// Calculate perceptual color distance using simplified CAM16 distance.
double computeColorDistance(Color c1, Color c2) {
  final cam1 = mcu.Cam16.fromInt(c1.value);
  final cam2 = mcu.Cam16.fromInt(c2.value);

  final dH = (cam1.hue - cam2.hue).abs();
  final dC = (cam1.chroma - cam2.chroma).abs();
  final dJ = (cam1.j - cam2.j).abs(); // Lightness

  // Simplified perceptual distance
  return math.sqrt(dH * dH * 0.5 + dC * dC + dJ * dJ * 0.5);
}

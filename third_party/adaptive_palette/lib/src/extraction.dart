/// Color extraction using median-cut quantization.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'models.dart';

/// Helper class for median-cut algorithm color boxes.
class ColorBox {
  final List<int> colors;
  final List<int> counts;
  late int rmin, rmax, gmin, gmax, bmin, bmax, total;

  ColorBox(this.colors, this.counts) {
    rmin = 31;
    rmax = 0;
    gmin = 63;
    gmax = 0;
    bmin = 31;
    bmax = 0;
    total = 0;
    for (int i = 0; i < colors.length; i++) {
      final c = colors[i];
      final count = counts[i];
      final r = (c >> 11) & 31;
      final g = (c >> 5) & 63;
      final b = c & 31;
      if (r < rmin) rmin = r;
      if (r > rmax) rmax = r;
      if (g < gmin) gmin = g;
      if (g > gmax) gmax = g;
      if (b < bmin) bmin = b;
      if (b > bmax) bmax = b;
      total += count;
    }
  }

  int rangeR() => rmax - rmin;
  int rangeG() => gmax - gmin;
  int rangeB() => bmax - bmin;
}

/// Extract dominant colors using median-cut quantization.
///
/// Returns up to [k] color swatches sorted by population.
///
/// Algorithm:
/// 1. Build RGB565 histogram for speed
/// 2. Recursively split color space by median
/// 3. Average colors in each box weighted by population
List<Swatch> extractColors(Uint8List rgba, int k) {
  // Build histogram in RGB565 space for speed
  final Map<int, int> hist = {};
  for (int i = 0; i < rgba.length; i += 4) {
    final r = rgba[i];
    final g = rgba[i + 1];
    final b = rgba[i + 2];
    final a = rgba[i + 3];
    if (a < 16) continue; // skip near-transparent
    final key = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
    hist.update(key, (v) => v + 1, ifAbsent: () => 1);
  }

  if (hist.isEmpty) return [];

  // Color boxes to split
  List<ColorBox> boxes = [
    ColorBox(
      hist.keys.toList(growable: false),
      hist.values.toList(growable: false),
    ),
  ];

  int desired = math.max(2, k);
  while (boxes.length < desired) {
    // pick the box with largest range
    boxes.sort(
      (a, b) => ((b.rangeR() + b.rangeG() + b.rangeB()) -
          (a.rangeR() + a.rangeG() + a.rangeB())),
    );
    final box = boxes.first;
    if (box.colors.length <= 1) break;

    // Decide split channel
    int channel = 0; // 0=r,1=g,2=b
    final rRange = box.rangeR();
    final gRange = box.rangeG();
    final bRange = box.rangeB();
    if (gRange >= rRange && gRange >= bRange) {
      channel = 1;
    } else if (bRange >= rRange && bRange >= gRange) {
      channel = 2;
    }

    // Sort colors in box by channel
    List<int> idx = List.generate(box.colors.length, (i) => i);
    idx.sort((i, j) {
      final ci = box.colors[i];
      final cj = box.colors[j];
      int vi, vj;
      if (channel == 0) {
        vi = (ci >> 11) & 31;
        vj = (cj >> 11) & 31;
      } else if (channel == 1) {
        vi = (ci >> 5) & 63;
        vj = (cj >> 5) & 63;
      } else {
        vi = ci & 31;
        vj = cj & 31;
      }
      return vi.compareTo(vj);
    });

    // Prefix sums to find median by population
    final counts = [for (final i in idx) box.counts[i]];
    int total = counts.fold<int>(0, (a, b) => a + b);
    int acc = 0;
    int cut = 0;
    for (int i = 0; i < counts.length; i++) {
      acc += counts[i];
      if (acc >= total ~/ 2) {
        cut = i;
        break;
      }
    }
    if (cut <= 0 || cut >= idx.length - 1) break;

    List<int> colorsA = [for (int i = 0; i <= cut; i++) box.colors[idx[i]]];
    List<int> countsA = [for (int i = 0; i <= cut; i++) box.counts[idx[i]]];
    List<int> colorsB = [
      for (int i = cut + 1; i < idx.length; i++) box.colors[idx[i]],
    ];
    List<int> countsB = [
      for (int i = cut + 1; i < idx.length; i++) box.counts[idx[i]],
    ];

    boxes.removeAt(0);
    boxes
      ..add(ColorBox(colorsA, countsA))
      ..add(ColorBox(colorsB, countsB));
  }

  // Average color for each box weighted by population
  List<Swatch> out = [];
  for (final box in boxes) {
    int rs = 0, gs = 0, bs = 0, tot = 0;
    for (int i = 0; i < box.colors.length; i++) {
      final c = box.colors[i];
      final count = box.counts[i];
      final r = (c >> 11) & 31;
      final g = (c >> 5) & 63;
      final b = c & 31;
      rs += (r << 3) * count;
      gs += (g << 2) * count;
      bs += (b << 3) * count;
      tot += count;
    }
    if (tot == 0) continue;
    final r8 = (rs / tot).round().clamp(0, 255);
    final g8 = (gs / tot).round().clamp(0, 255);
    final b8 = (bs / tot).round().clamp(0, 255);
    out.add(Swatch(Color.fromARGB(0xFF, r8, g8, b8), tot));
  }

  // Sort by population
  out.sort((a, b) => b.population.compareTo(a.population));
  return out;
}

/// Downsample image to target size using nearest-neighbor sampling.
///
/// Maintains aspect ratio and returns new pixel data.
Uint8List downsampleImage(Uint8List src, int w, int h, int target) {
  if (w <= target && h <= target) return src; // already small enough

  // Maintain aspect ratio
  final aspect = w / h;
  int tw, th;
  if (aspect >= 1.0) {
    tw = target;
    th = (target / aspect).round();
  } else {
    th = target;
    tw = (target * aspect).round();
  }

  final out = Uint8List(tw * th * 4);
  for (int y = 0; y < th; y++) {
    final sy = (y * (h - 1) / (th - 1)).round();
    for (int x = 0; x < tw; x++) {
      final sx = (x * (w - 1) / (tw - 1)).round();
      final si = (sy * w + sx) * 4;
      final di = (y * tw + x) * 4;
      out[di] = src[si];
      out[di + 1] = src[si + 1];
      out[di + 2] = src[si + 2];
      out[di + 3] = src[si + 3];
    }
  }
  return out;
}

/// Load ui.Image from ImageProvider.
Future<ui.Image> loadImageFromProvider(ImageProvider provider) async {
  final completer = Completer<ui.Image>();
  final stream = provider.resolve(const ImageConfiguration());
  ImageStreamListener? listener;
  listener = ImageStreamListener(
    (ImageInfo info, bool _) {
      completer.complete(info.image);
      stream.removeListener(listener!);
    },
    onError: (Object e, StackTrace? st) {
      if (!completer.isCompleted) completer.completeError(e, st);
      stream.removeListener(listener!);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

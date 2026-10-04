// SPDX-License-Identifier: MIT
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/theme/theme_assets.dart';
import 'package:ngskg_plus/utils/palette_extractor.dart';
import 'package:ngskg_plus/widgets/local_cover_art.dart';

Future<Uint8List> _rectanglePng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 800, 400),
      Paint()..color = const Color(0xFF3366CC));
  final picture = recorder.endRecording();
  final image = await picture.toImage(800, 400).timeout(const Duration(seconds: 10));
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<(int, int)> _decodedSize(ImageProvider provider) async {
  final result = Completer<(int, int)>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;
  listener = ImageStreamListener((info, _) {
    final size = (info.image.width, info.image.height);
    stream.removeListener(listener);
    info.dispose();
    result.complete(size);
  }, onError: (Object error, StackTrace? stack) {
    stream.removeListener(listener);
    result.completeError(error, stack);
  });
  stream.addListener(listener);
  try {
    return await result.future.timeout(const Duration(seconds: 10));
  } finally {
    stream.removeListener(listener);
  }
}

Widget _app(Widget child) => MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 3),
          child: Center(child: child),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets('内存封面按显示像素降采样且保留矩形比例', (tester) async {
    final bytes = (await tester.runAsync(_rectanglePng))!;
    await tester.pumpWidget(_app(LocalCoverArt(size: 48, coverData: bytes)));
    final image = tester.widget<Image>(find.byType(Image));
    final resized = image.image as ResizeImage;
    expect(resized.width, 144);
    expect(resized.height, 144);
    expect(resized.policy, ResizeImagePolicy.fit);
    final decoded = await tester.runAsync(() => _decodedSize(resized));
    expect(decoded, (144, 72));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('文件封面和主题图降采样时不拉伸矩形图片', (tester) async {
    final bytes = (await tester.runAsync(_rectanglePng))!;
    final file = (await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp('ngskg-image-test-');
      return File('${directory.path}/cover.png').writeAsBytes(bytes);
    }))!;
    try {
      await tester.pumpWidget(_app(LocalCoverArt(size: 48, url: file.path)));
      var image = tester.widget<Image>(find.byType(Image));
      var resized = image.image as ResizeImage;
      expect(resized.policy, ResizeImagePolicy.fit);
      expect(resized.width, 144);
      expect(resized.height, 144);
      expect(resized.imageProvider, isA<FileImage>());

      await tester.pumpWidget(_app(ThemeImage(
        assetPath: file.path,
        width: 120,
        height: 120,
      )));
      image = tester.widget<Image>(find.byType(Image));
      resized = image.image as ResizeImage;
      expect(resized.policy, ResizeImagePolicy.fit);
      expect(resized.width, 360);
      expect(resized.height, 360);
      expect(resized.imageProvider, isA<FileImage>());
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await tester.runAsync(() => file.parent.delete(recursive: true));
    }
  });

  testWidgets('同一封面并发提取共用 Future，清缓存后重新提取', (tester) async {
    final bytes = (await tester.runAsync(_rectanglePng))!;
    final extractor = PaletteExtractor.instance;
    extractor.clearCache();
    addTearDown(extractor.clearCache);
    await tester.runAsync(() async {
      final provider = MemoryImage(bytes);
      final first = extractor.extractFromProvider(provider, 'cover');
      final second = extractor.extractFromProvider(provider, 'cover');
      expect(identical(first, second), isTrue);
      final palette = await first.timeout(const Duration(seconds: 15));
      expect(identical(await second, palette), isTrue);
      expect(identical(await extractor.extractFromProvider(provider, 'cover'),
          palette), isTrue);
      expect(identical(palette, PaletteExtractor.fallbackPalette), isFalse);

      extractor.clearCache();
      final refreshed = await extractor.extractFromProvider(provider, 'cover')
          .timeout(const Duration(seconds: 15));
      expect(identical(refreshed, palette), isFalse);
      expect(refreshed.dominant, palette.dominant);
    });
  });
}

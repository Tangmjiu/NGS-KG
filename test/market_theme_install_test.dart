// SPDX-License-Identifier: MIT
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/providers/theme_provider.dart';
import 'package:ngskg_plus/services/market_service.dart';
import 'package:ngskg_plus/theme/theme_assets.dart';
import 'package:ngskg_plus/theme/theme_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _themeZip(int revision) {
  final archive = Archive();
  void add(String name, List<int> data) =>
      archive.addFile(ArchiveFile(name, data.length, data));
  add(
      'manifest.json',
      utf8.encode(jsonEncode({
        'name': '主题 $revision',
        'author': '作者',
        'version': 3,
        'assets': {'album_placeholder': 'cover.png'},
        'wallpaper': {'player': 'wallpaper.png'},
      })));
  add('cover.png', [revision, 1]);
  add('wallpaper.png', [revision, 2]);
  add('preview.png', [revision, 3]);
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThemeAssets.resetToDefault();
  });
  tearDown(ThemeAssets.resetToDefault);

  test('市场记录失败仍返回已提交主题，当前同ID本地主题及时换用新资源', () async {
    final root = await Directory.systemTemp.createTemp('market-theme-update-');
    addTearDown(() => root.delete(recursive: true));
    final provider = ThemeProvider();
    addTearDown(provider.dispose);
    await provider.init();
    final original = (await ThemeLoader.parseZipBytes(_themeZip(1), 'art.zip',
        themesDirectory: root))!;
    provider.addMarketPack(original);
    await provider.selectPack('art');
    expect(await MarketService.getInstalledIds(), isEmpty);

    final recorded = <String>[];
    String? nameAtRecord;
    final installed = await MarketService.installTheme(
      _themeZip(2),
      'art.zip',
      themesDirectory: root,
      recordInstalled: (id) async {
        recorded.add(id);
        final committed =
            await ThemeLoader.loadPackFromDisk(id, themesDirectory: root);
        nameAtRecord = committed?.name;
        throw StateError('模拟市场安装记录写入失败');
      },
    );

    expect(installed, isNotNull);
    expect(recorded, ['art']);
    expect(nameAtRecord, '主题 2');
    final updated = installed!;
    final activated = Completer<void>();
    provider.addListener(() {
      if (!activated.isCompleted && identical(provider.currentPack, updated)) {
        activated.complete();
      }
    });
    // 与市场页面收到成功结果后的处理一致，不需重启或重新选择主题。
    provider.addMarketPack(updated);
    await activated.future.timeout(const Duration(seconds: 5));

    expect(provider.selectedPackId, 'art');
    expect(provider.currentPack, same(updated));
    expect(
        ThemeAssets.albumPlaceholder, updated.assetFiles!['album_placeholder']);
    expect(ThemeAssets.playerBg, updated.playerBgPath);
    expect(await File(ThemeAssets.albumPlaceholder).readAsBytes(), [2, 1]);
    expect(await File(ThemeAssets.playerBg).readAsBytes(), [2, 2]);
    expect(await File(updated.previewPath!).readAsBytes(), [2, 3]);
    expect(
        await File(original.assetFiles!['album_placeholder']!).exists(), false);
    expect(await File(original.playerBgPath!).exists(), false);
    expect(await ThemeLoader.getImportedThemeIds(), ['art']);
    final restored =
        await ThemeLoader.loadPackFromDisk('art', themesDirectory: root);
    expect(restored!.toJson(), updated.toJson());
  });

  test('主题安装本身失败仍返回null，不尝试写市场记录', () async {
    final root = await Directory.systemTemp.createTemp('market-theme-invalid-');
    addTearDown(() => root.delete(recursive: true));
    final original = (await ThemeLoader.parseZipBytes(_themeZip(1), 'art.zip',
        themesDirectory: root))!;
    var attemptedRecord = false;

    final result = await MarketService.installTheme(
      Uint8List.fromList([1, 2, 3]),
      'art.zip',
      themesDirectory: root,
      recordInstalled: (_) async => attemptedRecord = true,
    );

    expect(result, isNull);
    expect(attemptedRecord, false);
    final restored =
        await ThemeLoader.loadPackFromDisk('art', themesDirectory: root);
    expect(restored!.toJson(), original.toJson());
    expect(await File(original.playerBgPath!).readAsBytes(), [1, 2]);
  });
}

// SPDX-License-Identifier: MIT
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ngskg_plus/models/lyric_settings.dart';
import 'package:ngskg_plus/models/theme_pack.dart';
import 'package:ngskg_plus/providers/theme_provider.dart';
import 'package:ngskg_plus/theme/app_theme.dart';
import 'package:ngskg_plus/theme/app_theme_tokens.dart';
import 'package:ngskg_plus/theme/theme_assets.dart';
import 'package:ngskg_plus/theme/theme_loader.dart';
import 'package:ngskg_plus/theme/theme_settings_store.dart';

Map<String, dynamic> _manifest(int version) => {
      'name': '旧主题',
      'author': '作者',
      'version': version,
      'colors': {
        'light': {'primary': '#336699', 'surface': '#F9F6EF'},
        'dark': {'primary': '#AABBCC', 'surface': '#182025'},
      },
      'typography': {
        'family': 'TestFont',
        'weight': {'regular': 'fonts/regular.ttf', 'bold': 'fonts/bold.ttf'},
      },
      'shapes': {'xs': 3, 'sm': 7, 'md': 11, 'lg': 19, 'xl': 27},
      'assets': {'album_placeholder': 'images/cover.png'},
      'wallpaper': {'player': 'images/wallpaper.png'},
      'motion': {'durationScale': 1.5, 'curve': 'linear'},
      'components': {
        'card': {'elevation': 2}
      },
      'lyricSettings': {'fontSize': 20, 'centerAlign': true, 'fontWeight': 600},
      if (version == 3) 'design': {'cardRadius': 30, 'pagePadding': 24},
    };

List<int> _zip(Map<String, dynamic> manifest,
    {Map<String, List<int>> resources = const {}}) {
  final archive = Archive();
  void add(String name, List<int> content) =>
      archive.addFile(ArchiveFile(name, content.length, content));
  add('manifest.json', utf8.encode(jsonEncode(manifest)));
  for (final entry in <String, List<int>>{
    'preview.png': [1, 2],
    'images/cover.png': [3, 4],
    'images/wallpaper.png': [5, 6],
    'fonts/regular.ttf': [7, 8],
    'fonts/bold.ttf': [9, 10],
    ...resources,
  }.entries) {
    add(entry.key, entry.value);
  }
  return ZipEncoder().encode(archive);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThemeAssets.resetToDefault();
  });

  test('设计参数约束异常值并支持插值', () {
    final tokens = AppThemeTokens.fromJson({
      'pagePadding': -20,
      'sectionSpacing': double.infinity,
      'cardRadius': 500,
      'controlRadius': 'oops',
      'contentMaxWidth': 10,
    });
    expect(tokens.pagePadding, 8);
    expect(tokens.sectionSpacing, 28);
    expect(tokens.cardRadius, 48);
    expect(tokens.controlRadius, 16);
    expect(tokens.contentMaxWidth, 600);
    expect(
        AppThemeTokens.defaults
            .lerp(const AppThemeTokens(pagePadding: 40), 0.5)
            .pagePadding,
        30);
  });

  for (final version in [1, 2, 3]) {
    test('v$version ZIP 安装与重启恢复保留颜色、字体、图片、形状和歌词', () async {
      final root = await Directory.systemTemp.createTemp('theme-migration-');
      addTearDown(() => root.delete(recursive: true));
      final pack = await ThemeLoader.parseZipBytes(
          _zip(_manifest(version)), 'legacy_$version.zip',
          themesDirectory: root);
      expect(pack, isNotNull);
      final restored = await ThemeLoader.loadPackFromDisk('legacy_$version',
          themesDirectory: root);
      expect(restored, isNotNull);
      expect(restored!.id, 'legacy_$version');
      expect(restored.version, version);
      expect(restored.lightScheme!.primary, const Color(0xFF336699));
      expect(restored.lightScheme!.surface, const Color(0xFFF9F6EF));
      expect(restored.darkScheme!.surface, const Color(0xFF182025));
      expect(restored.fontFamily, 'TestFont');
      expect(
          await File(restored.fontWeightFiles!.regular).readAsBytes(), [7, 8]);
      expect(
          await File(restored.fontWeightFiles!.bold!).readAsBytes(), [9, 10]);
      expect(
          await File(restored.assetFiles!['album_placeholder']!).readAsBytes(),
          [3, 4]);
      expect(await File(restored.playerBgPath!).readAsBytes(), [5, 6]);
      expect(restored.shapes!['xl'], 27);
      expect(restored.motion.durationScale, 1.5);
      expect(restored.components.cardElevation, 2);
      expect(restored.lyricSettingsOverride!['fontSize'], 20);
      expect(restored.lyricSettingsOverride!['centerAlign'], true);
      expect(restored.tokens!.cardRadius, version == 3 ? 30 : 19);
      expect(restored.tokens!.controlRadius, 11);
      expect(await ThemeLoader.getImportedThemeIds(), ['legacy_$version']);
      final persisted = jsonDecode(
          await File('${root.path}/legacy_$version/manifest.json')
              .readAsString());
      expect(
          persisted['assetFiles']['album_placeholder'],
          allOf(startsWith('revisions/revision_'),
              endsWith('/images/album_placeholder.png')));
      expect(persisted['schemaVersion'], 3);
    });
  }

  test('同 ID 重装使用新资源路径，重启可恢复并清理旧资源', () async {
    final root = await Directory.systemTemp.createTemp('theme-reinstall-');
    addTearDown(() => root.delete(recursive: true));
    final original = (await ThemeLoader.parseZipBytes(
        _zip(_manifest(3)), 'art.zip',
        themesDirectory: root))!;
    final originalPaths = [
      original.previewPath!,
      original.assetFiles!['album_placeholder']!,
      original.playerBgPath!,
      original.fontWeightFiles!.regular,
      original.fontWeightFiles!.bold!,
    ];
    final replacement = (await ThemeLoader.parseZipBytes(
      _zip(_manifest(3)..['name'] = '更新后的主题', resources: {
        'preview.png': [11, 12],
        'images/cover.png': [13, 14],
        'images/wallpaper.png': [15, 16],
        'fonts/regular.ttf': [17, 18],
        'fonts/bold.ttf': [19, 20],
      }),
      'art.zip',
      themesDirectory: root,
    ))!;
    final replacementPaths = [
      replacement.previewPath!,
      replacement.assetFiles!['album_placeholder']!,
      replacement.playerBgPath!,
      replacement.fontWeightFiles!.regular,
      replacement.fontWeightFiles!.bold!,
    ];
    expect(replacement.id, original.id);
    expect(replacement.name, '更新后的主题');
    for (var i = 0; i < originalPaths.length; i++) {
      expect(replacementPaths[i], isNot(originalPaths[i]));
      expect(await File(originalPaths[i]).exists(), false);
      expect(await File(replacementPaths[i]).readAsBytes(),
          [11 + i * 2, 12 + i * 2]);
    }
    // FileImage 以路径作为缓存键；重装后旧图片缓存不会再次命中。
    expect(FileImage(File(replacementPaths[1])),
        isNot(FileImage(File(originalPaths[1]))));
    final restored =
        (await ThemeLoader.loadPackFromDisk('art', themesDirectory: root))!;
    expect(restored.toJson(), replacement.toJson());
    expect(await ThemeLoader.getImportedThemeIds(), ['art']);
    expect(await Directory('${root.path}/art/revisions').list().length, 1);
    expect(
        await Directory('${root.path}/art')
            .list()
            .where((entry) => entry.path.endsWith('.json'))
            .length,
        1);
  });

  for (final hasOriginal in [false, true]) {
    test('${hasOriginal ? '同 ID 重装' : '首次安装'}写入中途失败不留下新资源或破坏原主题', () async {
      final root = await Directory.systemTemp.createTemp('theme-rollback-');
      addTearDown(() => root.delete(recursive: true));
      final manifestFile = File('${root.path}/art/manifest.json');
      String? originalManifest;
      ThemePack? original;
      List<String>? originalFiles;
      if (hasOriginal) {
        original = (await ThemeLoader.parseZipBytes(
            _zip(_manifest(3)), 'art.zip',
            themesDirectory: root))!;
        originalManifest = await manifestFile.readAsString();
        originalFiles = await Directory('${root.path}/art')
            .list(recursive: true)
            .map((entry) => entry.path)
            .toList();
        originalFiles.sort();
      }
      // 第一张图写入成功后，第二张图的超长扩展名触发真实文件写入失败。
      final invalidImage = 'images/failure.${List.filled(300, 'x').join()}';
      final brokenManifest = _manifest(3)
        ..['assets'] = {
          'album_placeholder': 'images/cover.png',
          'load_failed': invalidImage,
        };
      final result = await ThemeLoader.parseZipBytes(
        _zip(brokenManifest, resources: {
          'images/cover.png': [13, 14],
          invalidImage: [15, 16],
        }),
        'art.zip',
        themesDirectory: root,
      );
      expect(result, isNull);
      expect(
          await ThemeLoader.getImportedThemeIds(), hasOriginal ? ['art'] : []);
      if (hasOriginal) {
        expect(await manifestFile.readAsString(), originalManifest);
        expect(
            await File(original!.assetFiles!['album_placeholder']!)
                .readAsBytes(),
            [3, 4]);
        expect(await File(original.playerBgPath!).readAsBytes(), [5, 6]);
        expect(await File(original.fontWeightFiles!.regular).readAsBytes(),
            [7, 8]);
        final restored =
            await ThemeLoader.loadPackFromDisk('art', themesDirectory: root);
        expect(restored!.toJson(), original.toJson());
        final remaining = await Directory('${root.path}/art')
            .list(recursive: true)
            .map((entry) => entry.path)
            .toList();
        remaining.sort();
        expect(remaining, originalFiles);
      } else {
        expect(await manifestFile.exists(), false);
        expect(
            await Directory('${root.path}/art/revisions').list().isEmpty, true);
      }
    });
  }

  test('旧绝对路径主题可以读取，重装仅清理安装目录内的旧资源', () async {
    final root = await Directory.systemTemp.createTemp('theme-absolute-');
    addTearDown(() => root.delete(recursive: true));
    final dir = Directory('${root.path}/legacy');
    await dir.create();
    final cover = File('${dir.path}/cover.png');
    final externalWallpaper = File('${root.path}/external.png');
    await cover.writeAsBytes([1, 2]);
    await externalWallpaper.writeAsBytes([3, 4]);
    await File('${dir.path}/manifest.json').writeAsString(jsonEncode({
      'id': 'legacy',
      'name': '旧磁盘主题',
      'author': '作者',
      'assetFiles': {'album_placeholder': cover.path},
      'playerBgPath': externalWallpaper.path,
    }));
    final original =
        (await ThemeLoader.loadPackFromDisk('legacy', themesDirectory: root))!;
    expect(original.assetFiles!['album_placeholder'], cover.path);
    expect(original.playerBgPath, externalWallpaper.path);
    final replacement = await ThemeLoader.parseZipBytes(
        _zip(_manifest(3)), 'legacy.zip',
        themesDirectory: root);
    expect(replacement, isNotNull);
    expect(await cover.exists(), false);
    expect(await externalWallpaper.readAsBytes(), [3, 4]);
    expect(await File(replacement!.playerBgPath!).readAsBytes(), [5, 6]);
  });

  test('更新不会沿安装目录内的 revision 符号链接写入或清理外部资源', () async {
    final root = await Directory.systemTemp.createTemp('theme-link-');
    addTearDown(() => root.delete(recursive: true));
    final external = await Directory.systemTemp.createTemp('theme-external-');
    addTearDown(() => external.delete(recursive: true));
    final externalFile = File('${external.path}/keep.png');
    await externalFile.writeAsBytes([1, 2]);
    final dir = await Directory('${root.path}/legacy').create();
    final manifestFile = File('${dir.path}/manifest.json');
    final originalManifest = jsonEncode({
      'id': 'legacy',
      'name': '旧磁盘主题',
      'author': '作者',
      'assetFiles': {'album_placeholder': externalFile.path},
    });
    await manifestFile.writeAsString(originalManifest);
    await Link('${dir.path}/revisions').create(external.path);

    final replacement = await ThemeLoader.parseZipBytes(
        _zip(_manifest(3)), 'legacy.zip',
        themesDirectory: root);

    expect(replacement, isNull);
    expect(await manifestFile.readAsString(), originalManifest);
    expect(await externalFile.readAsBytes(), [1, 2]);
    expect(await external.list().map((entry) => entry.path).toList(),
        [externalFile.path]);
  });

  test('旧磁盘 JSON 无需重新导入即可迁移，颜色含透明度可往返', () async {
    final root = await Directory.systemTemp.createTemp('theme-disk-');
    addTearDown(() => root.delete(recursive: true));
    final dir = Directory('${root.path}/installed');
    await dir.create();
    await File('${dir.path}/manifest.json').writeAsString(jsonEncode({
      'id': 'installed',
      'name': 'Installed',
      'author': 'Author',
      'version': 2,
      'lightScheme': {'primary': '#88445566', 'onInverseSurface': '#AABBCC'},
      'assetFiles': {'album_placeholder': 'cover.png'},
      'fontFamily': 'Existing',
      'fontWeightFiles': {'regular': 'fonts/a.ttf'},
      'playerBgPath': 'wallpaper.png',
      'lyricSettingsOverride': {'fontSize': 24},
      'shapes': {'lg': 17, 'md': 13},
    }));
    final pack = (await ThemeLoader.loadPackFromDisk('installed',
        themesDirectory: root))!;
    expect(pack.assetFiles!['album_placeholder'], '${dir.path}/cover.png');
    expect(pack.fontWeightFiles!.regular, '${dir.path}/fonts/a.ttf');
    expect(pack.playerBgPath, '${dir.path}/wallpaper.png');
    expect(pack.tokens!.cardRadius, 17);
    final roundtrip = ThemePack.fromJson(pack.toJson());
    expect(roundtrip.lightScheme!.primary, const Color(0x88445566));
    expect(roundtrip.lightScheme!.onInverseSurface, const Color(0xFFAABBCC));
    expect(roundtrip.lyricSettingsOverride!['fontSize'], 24);
  });

  test('没有清单或未知格式的 ZIP 不会产生已安装记录', () async {
    final archive = Archive()..addFile(ArchiveFile('readme.txt', 1, [1]));
    expect(
        await ThemeLoader.parseZipBytes(
            ZipEncoder().encode(archive), 'empty.zip'),
        isNull);
    expect(await ThemeLoader.parseZipBytes(_zip(_manifest(4)), 'future.zip'),
        isNull);
    expect(await ThemeLoader.getImportedThemeIds(), isEmpty);
  });

  test('旧偏好迁移保留主题 ID、强调色、Monet、字体显示和歌词手动覆盖', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': ThemeMode.dark.index,
      'theme_selected_pack': 'md3_default',
      'theme_accent': 'custom',
      'theme_custom_color': 0xFF123456,
      'theme_use_monet': true,
      'theme_flow_light': true,
      'theme_show_hi_res': true,
      'theme_support_dismissed': true,
      'theme_lyric_settings': jsonEncode(
          const LyricSettings(fontSize: 23, fontWeight: 700).toJson()),
    });
    final store = ThemeSettingsStore();
    final settings = await store.load();
    expect(settings.mode, ThemeMode.dark);
    expect(settings.selectedPackId, 'md3_default');
    expect(settings.customColor, const Color(0xFF123456));
    expect(settings.accentKey, 'custom');
    expect(settings.useMonet, true);
    expect(settings.flowLight, true);
    expect(settings.showHiResBadge, true);
    expect(settings.supportDismissed, true);
    expect(settings.lyricOverride!.fontSize, 23);
    expect(settings.lyricOverride!.fontWeight, 700);
    await store.save(settings);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_selected_pack', 'ngs_nagisa');
    expect((await store.load()).selectedPackId, 'md3_default');
  });

  for (final packId in [
    'ngs_default',
    'ngs_nagisa',
    'md3_default',
    'imported_theme',
  ]) {
    for (final fromSnapshot in [false, true]) {
      test('${fromSnapshot ? 'v3 快照' : '旧偏好'}读取 $packId 仅转换兼容 ID 并保留所有设置',
          () async {
        final original = ThemeSettings(
          mode: ThemeMode.dark,
          selectedPackId: packId,
          accentKey: 'custom',
          customColor: const Color(0xFF123456),
          useMonet: true,
          flowLight: true,
          showHiResBadge: false,
          lyricOverride: const LyricSettings(
            fontSize: 23,
            fontWeight: 700,
            centerAlign: true,
            blurEffect: true,
          ),
          launchCount: 7,
          firstLaunchDate: 1700000000000,
          supportDismissed: true,
        );
        SharedPreferences.setMockInitialValues(fromSnapshot
            ? {
                ThemeSettingsStore.settingsKey: jsonEncode(original.toJson()),
              }
            : {
                'theme_mode': original.mode.index,
                'theme_selected_pack': original.selectedPackId,
                'theme_accent': original.accentKey,
                'theme_custom_color': original.customColor.toARGB32(),
                'theme_use_monet': original.useMonet,
                'theme_flow_light': original.flowLight,
                'theme_show_hi_res': original.showHiResBadge,
                'theme_lyric_settings':
                    jsonEncode(original.lyricOverride!.toJson()),
                'theme_launch_count': original.launchCount,
                'theme_first_launch_date': original.firstLaunchDate,
                'theme_support_dismissed': original.supportDismissed,
              });
        final expected = original
            .copyWith(
              selectedPackId: packId == 'ngs_default' ? 'ngs_nagisa' : packId,
            )
            .toJson();
        final store = ThemeSettingsStore();
        final restored = await store.load();
        expect(restored.toJson(), expected);

        await store.save(restored);

        final prefs = await SharedPreferences.getInstance();
        expect(jsonDecode(prefs.getString(ThemeSettingsStore.settingsKey)!),
            expected);
        expect((await store.load()).toJson(), expected);
      });
    }
  }

  test('新安装和无显式选择的旧用户均默认 Ran Nagisa，Hi-Res 保留各自默认值', () async {
    expect(const ThemeSettings().selectedPackId, 'ngs_nagisa');
    final fresh = await ThemeSettingsStore().load();
    expect(fresh.selectedPackId, 'ngs_nagisa');
    expect(fresh.showHiResBadge, false);
    SharedPreferences.setMockInitialValues({'theme_launch_count': 2});
    final existing = await ThemeSettingsStore().load();
    expect(existing.selectedPackId, 'ngs_nagisa');
    expect(existing.showHiResBadge, true);
  });

  test('内置列表保留 Ran Nagisa 与 MD3，默认主题使用原有插画', () async {
    final provider = ThemeProvider();
    addTearDown(provider.dispose);
    await provider.init();

    expect(
        provider.packs.map((pack) => pack.id), ['ngs_nagisa', 'md3_default']);
    expect(provider.currentPack, ngsNagisa);
    expect(provider.selectedPackId, 'ngs_nagisa');
    expect(ThemeAssets.emptyContent, 'assets/images/empty_content.png');
    expect(ThemeAssets.emptyPlaylist, 'assets/images/empty_playlist.png');
    expect(ThemeAssets.loadFailed, 'assets/images/load_failed.png');
  });

  test('主题暂时不可读取时仍保留导入主题选择', () async {
    SharedPreferences.setMockInitialValues({
      ThemeSettingsStore.settingsKey: jsonEncode(
        const ThemeSettings(selectedPackId: 'unavailable_theme').toJson(),
      ),
    });
    final provider = ThemeProvider();
    addTearDown(provider.dispose);
    await provider.init();

    expect(provider.currentPack, ngsNagisa);
    expect(provider.selectedPackId, 'unavailable_theme');
    expect((await ThemeSettingsStore().load()).selectedPackId,
        'unavailable_theme');
  });

  test('切换主题资源不残留，用户歌词设置高于主题默认值', () async {
    final provider = ThemeProvider();
    addTearDown(provider.dispose);
    await provider.init();
    provider.addMarketPack(const ThemePack(
      id: 'art',
      name: 'Art',
      author: 'Author',
      assetFiles: {'album_placeholder': '/test/album.png'},
      lyricSettingsOverride: {'fontSize': 21},
    ));
    await provider.selectPack('art');
    expect(ThemeAssets.albumPlaceholder, '/test/album.png');
    expect(provider.lyricSettings.fontSize, 21);
    await provider.setLyricSettings(const LyricSettings(fontSize: 25));
    await provider.selectPack('ngs_nagisa');
    expect(ThemeAssets.albumPlaceholder, '');
    expect(provider.lyricSettings.fontSize, 25);
    await provider.selectPack('art');
    expect(provider.lyricSettings.fontSize, 25);
    expect((await ThemeSettingsStore().load()).selectedPackId, 'art');
  });

  test('市场安装记录删除失败仍删除当前主题并持久化恢复默认主题', () async {
    final root = await Directory.systemTemp.createTemp('theme-delete-');
    addTearDown(() => root.delete(recursive: true));
    final uninstalled = <String>[];
    final provider = ThemeProvider(
      deleteTheme: (id) => ThemeLoader.deleteTheme(id, themesDirectory: root),
      uninstallMarketTheme: (id) async {
        uninstalled.add(id);
        throw StateError('模拟市场记录删除失败');
      },
    );
    addTearDown(provider.dispose);
    await provider.init();
    final manifest = _manifest(3)..remove('typography');
    final pack = (await ThemeLoader.parseZipBytes(_zip(manifest), 'art.zip',
        themesDirectory: root))!;
    provider.addMarketPack(pack);
    await provider.selectPack('art');
    expect(ThemeAssets.albumPlaceholder, pack.assetFiles!['album_placeholder']);
    expect(ThemeAssets.playerBg, pack.playerBgPath);

    await provider.deletePack('art');

    expect(uninstalled, ['art']);
    expect(await Directory('${root.path}/art').exists(), false);
    expect(await ThemeLoader.getImportedThemeIds(), isEmpty);
    expect(provider.packs.any((pack) => pack.id == 'art'), false);
    expect(provider.currentPack, ngsNagisa);
    expect(provider.selectedPackId, 'ngs_nagisa');
    expect(ThemeAssets.albumPlaceholder, '');
    expect(ThemeAssets.playerBg, '');
    expect(ThemeAssets.emptyContent, 'assets/images/empty_content.png');
    expect((await ThemeSettingsStore().load()).selectedPackId, 'ngs_nagisa');
  });

  test('主题工厂使用相同令牌、完整旧色板与自定义字体', () {
    final pack = ThemePack.fromJson(_manifest(3));
    final theme = AppTheme.build(pack.lightScheme!, pack);
    expect(theme.useMaterial3, true);
    expect(theme.colorScheme.surface, const Color(0xFFF9F6EF));
    expect(theme.extension<AppThemeTokens>()!.cardRadius, 30);
    expect(theme.textTheme.bodyLarge!.fontFamily, 'TestFont');
    expect(theme.cardTheme.elevation, 2);
    expect((theme.cardTheme.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(30));
    expect(ngsNagisa.id, 'ngs_nagisa');
    expect(ngsNagisa.version, 3);
    expect(ngsNagisa.tokens, AppThemeTokens.defaults);
    expect(ngsNagisa.lightScheme!.primary, const Color(0xFFFF6633));
    expect(md3Default.lightScheme, isNull);
  });
}

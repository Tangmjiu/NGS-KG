import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import '../models/theme_pack.dart';

/// ZIP 主题导入引擎
///
/// 解析 manifest v2，返回 ThemePack。
class ThemeLoader {
  static const _themesPrefsKey = 'imported_themes_v2';

  // ─── 公开方法 ───

  /// 从文件选择器导入 ZIP 主题包
  static Future<ThemePack?> importFromPicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) return null;

      return parseZipBytes(bytes!, file.name);
    } catch (e, s) {
      Log.e('ThemeLoader', 'import error', e, s);
      return null;
    }
  }

  /// 从字节数据解析 ZIP 主题包（公开给 MarketService 调用）
  static Future<ThemePack?> parseZipBytes(List<int> bytes, String fileName) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    if (archive.isEmpty) {
      Log.w('ThemeLoader', 'empty zip: $fileName');
      return null;
    }

    // 查找 manifest.json
    final manifestFile = archive.files.firstWhere(
      (f) => f.name == 'manifest.json' && f.isFile,
      orElse: () => _emptyFile(),
    );
    if (!manifestFile.isFile) {
      Log.w('ThemeLoader', 'manifest.json not found in $fileName');
      return null;
    }

    final manifestJson = jsonDecode(utf8.decode(manifestFile.content)) as Map<String, dynamic>;

    final name = manifestJson['name'] as String? ?? '未命名主题';
    final author = manifestJson['author'] as String? ?? '未知作者';
    final version = manifestJson['version'] as int? ?? 1;
    final description = manifestJson['description'] as String?;

    // ── 解析颜色 ──
    ColorScheme? lightScheme;
    ColorScheme? darkScheme;
    final colors = manifestJson['colors'] as Map<String, dynamic>?;
    if (colors != null) {
      lightScheme = _parseColorScheme(colors['light'] as Map<String, dynamic>?, Brightness.light);
      darkScheme = _parseColorScheme(colors['dark'] as Map<String, dynamic>?, Brightness.dark);
    }

    // ── 解析字体 ──
    String? fontFamily;
    FontWeightFiles? fontWeightFiles;
    final typography = manifestJson['typography'] as Map<String, dynamic>?;
    if (typography != null) {
      fontFamily = typography['family'] as String?;
      final rawWeight = typography['weight'] as Map<String, dynamic>?;
      if (rawWeight != null) {
        final regular = rawWeight['regular'] as String?;
        if (regular != null && regular.isNotEmpty) {
          final medium = rawWeight['medium'] as String?;
          final bold = rawWeight['bold'] as String?;
          fontWeightFiles = FontWeightFiles(regular: regular, medium: medium, bold: bold);
        }
      }
    }

    // ── 解析形状 ──
    Map<String, double>? shapes;
    final rawShapes = manifestJson['shapes'] as Map<String, dynamic>?;
    if (rawShapes != null) {
      shapes = rawShapes.map((k, v) => MapEntry(k, (v as num).toDouble()));
    }

    // ── 提取资源文件 ──
    final appDir = await _getThemeDir(_themeId(fileName));
    final assetFiles = <String, String>{};

    final rawAssets = manifestJson['assets'] as Map<String, dynamic>?;
    if (rawAssets != null) {
      const assetKeys = [
        'sthiswrong', 'codecrash', 'loading', 'ban', 'supportme', 'icon',
        'album_placeholder', 'playlist_placeholder', 'artist_placeholder',
        'empty_playlist', 'empty_content', 'load_failed',
      ];

      for (final key in assetKeys) {
        final zipPath = rawAssets[key] as String?;
        if (zipPath == null || zipPath.isEmpty) continue;

        final zipEntry = archive.files.firstWhere(
          (f) => f.name == zipPath && f.isFile,
          orElse: () => _emptyFile(),
        );
        if (!zipEntry.isFile) continue;

        final ext = zipPath.contains('.') ? '.${zipPath.split('.').last}' : '.png';
        final destName = '$key$ext';
        final destPath = '${appDir.path}/$destName';
        await File(destPath).writeAsBytes(zipEntry.content);
        assetFiles[key] = destPath;
      }
    }

    // ── 提取字体文件 ──
    if (fontWeightFiles != null && fontFamily != null) {
      final fontDir = Directory('${appDir.path}/fonts');
      if (!await fontDir.exists()) {
        await fontDir.create(recursive: true);
      }
      _extractFontFiles(archive, fontDir, fontWeightFiles!);
      // Update fontWeightFiles with absolute paths for FontLoader
      fontWeightFiles = FontWeightFiles(
        regular: '${fontDir.path}/${fontWeightFiles!.regular.split('/').last}',
        medium: fontWeightFiles!.medium != null
            ? '${fontDir.path}/${fontWeightFiles!.medium!.split('/').last}'
            : null,
        bold: fontWeightFiles!.bold != null
            ? '${fontDir.path}/${fontWeightFiles!.bold!.split('/').last}'
            : null,
      );
    }

    // ── 壁纸 ──
    String? playerBgPath;
    final wallpaper = manifestJson['wallpaper'] as Map<String, dynamic>?;
    if (wallpaper != null) {
      final bgPath = wallpaper['player'] as String?;
      if (bgPath != null && bgPath.isNotEmpty) {
        final zipEntry = archive.files.firstWhere(
          (f) => f.name == bgPath && f.isFile,
          orElse: () => _emptyFile(),
        );
        if (zipEntry.isFile) {
          final ext = bgPath.contains('.') ? '.${bgPath.split('.').last}' : '.png';
          final destPath = '${appDir.path}/player_bg$ext';
          await File(destPath).writeAsBytes(zipEntry.content);
          playerBgPath = destPath;
        }
      }
    }

    // ── 解析动效 ──
    var motionConfig = ThemeMotion.defaults;
    final rawMotion = manifestJson['motion'] as Map<String, dynamic>?;
    if (rawMotion != null) {
      final ds = rawMotion['durationScale'] as num?;
      final curve = rawMotion['curve'] as String?;
      motionConfig = ThemeMotion(
        durationScale: ds?.toDouble() ?? 1.0,
        curve: curve ?? 'emphasized',
      );
    }

    // ── 解析组件偏好 ──
    var componentsConfig = ThemeComponents.defaults;
    final rawComponents = manifestJson['components'] as Map<String, dynamic>?;
    if (rawComponents != null) {
      final navBar = rawComponents['navigationBar'] as Map<String, dynamic>?;
      final card = rawComponents['card'] as Map<String, dynamic>?;
      final dialog = rawComponents['dialog'] as Map<String, dynamic>?;
      componentsConfig = ThemeComponents(
        navigationBarElevation: (navBar?['elevation'] as num?)?.toDouble() ?? 0,
        cardElevation: (card?['elevation'] as num?)?.toDouble() ?? 0,
        dialogElevation: (dialog?['elevation'] as num?)?.toDouble() ?? 0,
      );
    }

    // ── 预览图 ──
    String? previewPath;
    final previewEntry = archive.files.firstWhere(
      (f) => f.name == 'preview.png' && f.isFile,
      orElse: () => _emptyFile(),
    );
    if (previewEntry.isFile) {
      previewPath = '${appDir.path}/preview.png';
      await File(previewPath).writeAsBytes(previewEntry.content);
    }

    // 记录已导入
    await _recordImported(_themeId(fileName));

    return ThemePack(
      id: _themeId(fileName),
      name: name,
      author: author,
      version: version,
      description: description,
      isBuiltIn: false,
      previewPath: previewPath,
      lightScheme: lightScheme,
      darkScheme: darkScheme,
      fontFamily: fontFamily,
      fontWeightFiles: fontWeightFiles,
      shapes: shapes,
      motion: motionConfig,
      components: componentsConfig,
      assetFiles: assetFiles.isNotEmpty ? assetFiles : null,
      playerBgPath: playerBgPath,
    );
  }

  // ─── 已导入主题管理 ───

  static Future<List<String>> getImportedThemeIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_themesPrefsKey) ?? [];
  }

  static Future<void> _recordImported(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_themesPrefsKey) ?? [];
    if (!list.contains(id)) {
      list.add(id);
      await prefs.setStringList(_themesPrefsKey, list);
    }
  }

  static Future<void> deleteTheme(String id) async {
    try {
      final dir = await _getThemeDir(id);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_themesPrefsKey) ?? [];
      list.remove(id);
      await prefs.setStringList(_themesPrefsKey, list);
    } catch (e, s) {
      Log.e('ThemeLoader', 'deleteTheme error', e, s);
    }
  }

  // ─── 内部工具 ───

  static String _themeId(String fileName) {
    return fileName.replaceAll(RegExp(r'\.zip$', caseSensitive: false), '');
  }

  static Future<Directory> _getThemeDir(String id) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/themes/$id');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 提取字体文件到主题字体目录
  static void _extractFontFiles(
    Archive archive,
    Directory fontDir,
    FontWeightFiles weightFiles,
  ) {
    void _extractOne(String path) {
      if (path.isEmpty) return;
      final entry = archive.files.firstWhere(
        (f) => f.name == path && f.isFile,
        orElse: () => _emptyFile(),
      );
      if (!entry.isFile) return;
      final name = path.split('/').last;
      File('${fontDir.path}/$name').writeAsBytesSync(entry.content);
    }

    _extractOne(weightFiles.regular);
    if (weightFiles.medium != null) _extractOne(weightFiles.medium!);
    if (weightFiles.bold != null) _extractOne(weightFiles.bold!);
  }

  /// 解析 manifest 中的 colorScheme map
  static ColorScheme? _parseColorScheme(Map<String, dynamic>? data, Brightness brightness) {
    if (data == null || data.isEmpty) return null;

    Color c(String key, Color fallback) {
      final v = data[key] as String?;
      if (v == null || v.isEmpty) return fallback;
      final h = v.replaceFirst('#', '');
      final val = int.tryParse(h, radix: 16);
      if (val == null) return fallback;
      return Color(0xFF000000 | val);
    }

    if (brightness == Brightness.light) {
      return ColorScheme.light(
        primary: c('primary', const Color(0xFF2CA1F4)),
        onPrimary: c('onPrimary', const Color(0xFFFFFFFF)),
        primaryContainer: c('primaryContainer', const Color(0xFFD2E5FF)),
        onPrimaryContainer: c('onPrimaryContainer', const Color(0xFF001D35)),
        secondary: c('secondary', const Color(0xFF565F71)),
        onSecondary: c('onSecondary', const Color(0xFFFFFFFF)),
        secondaryContainer: c('secondaryContainer', const Color(0xFFDAE2F9)),
        onSecondaryContainer: c('onSecondaryContainer', const Color(0xFF131C2B)),
        tertiary: c('tertiary', const Color(0xFF6E5676)),
        onTertiary: c('onTertiary', const Color(0xFFFFFFFF)),
        tertiaryContainer: c('tertiaryContainer', const Color(0xFFF8D8FE)),
        onTertiaryContainer: c('onTertiaryContainer', const Color(0xFF271430)),
        error: c('error', const Color(0xFFBA1A1A)),
        onError: c('onError', const Color(0xFFFFFFFF)),
        errorContainer: c('errorContainer', const Color(0xFFFFDAD6)),
        onErrorContainer: c('onErrorContainer', const Color(0xFF410002)),
        surface: c('surface', const Color(0xFFFDF8FF)),
        surfaceDim: c('surfaceDim', const Color(0xFFDED8E1)),
        surfaceBright: c('surfaceBright', const Color(0xFFFDF8FF)),
        surfaceContainerLowest: c('surfaceContainerLowest', const Color(0xFFFFFFFF)),
        surfaceContainerLow: c('surfaceContainerLow', const Color(0xFFF7F2FB)),
        surfaceContainer: c('surfaceContainer', const Color(0xFFF2ECF5)),
        surfaceContainerHigh: c('surfaceContainerHigh', const Color(0xFFEBE6EF)),
        surfaceContainerHighest: c('surfaceContainerHighest', const Color(0xFFE0DAE3)),
        onSurface: c('onSurface', const Color(0xFF1C1B1F)),
        onSurfaceVariant: c('onSurfaceVariant', const Color(0xFF49454F)),
        outline: c('outline', const Color(0xFF7A7580)),
        outlineVariant: c('outlineVariant', const Color(0xFFCAC4CD)),
        inverseSurface: c('inverseSurface', const Color(0xFF313033)),
        inversePrimary: c('inversePrimary', const Color(0xFFA9D0FF)),
      );
    } else {
      return ColorScheme.dark(
        primary: c('primary', const Color(0xFFAAC7FF)),
        onPrimary: c('onPrimary', const Color(0xFF003258)),
        primaryContainer: c('primaryContainer', const Color(0xFF00497D)),
        onPrimaryContainer: c('onPrimaryContainer', const Color(0xFFD2E5FF)),
        secondary: c('secondary', const Color(0xFFBEC6DC)),
        onSecondary: c('onSecondary', const Color(0xFF283141)),
        secondaryContainer: c('secondaryContainer', const Color(0xFF3E4759)),
        onSecondaryContainer: c('onSecondaryContainer', const Color(0xFFDAE2F9)),
        tertiary: c('tertiary', const Color(0xFFDBBDE2)),
        onTertiary: c('onTertiary', const Color(0xFF3D2846)),
        tertiaryContainer: c('tertiaryContainer', const Color(0xFF553F5D)),
        onTertiaryContainer: c('onTertiaryContainer', const Color(0xFFF8D8FE)),
        error: c('error', const Color(0xFFFFB4AB)),
        onError: c('onError', const Color(0xFF690005)),
        errorContainer: c('errorContainer', const Color(0xFF93000A)),
        onErrorContainer: c('onErrorContainer', const Color(0xFFFFDAD6)),
        surface: c('surface', const Color(0xFF141318)),
        surfaceDim: c('surfaceDim', const Color(0xFF141318)),
        surfaceBright: c('surfaceBright', const Color(0xFF3A383E)),
        surfaceContainerLowest: c('surfaceContainerLowest', const Color(0xFF0E0E13)),
        surfaceContainerLow: c('surfaceContainerLow', const Color(0xFF1C1B20)),
        surfaceContainer: c('surfaceContainer', const Color(0xFF201F24)),
        surfaceContainerHigh: c('surfaceContainerHigh', const Color(0xFF2B292F)),
        surfaceContainerHighest: c('surfaceContainerHighest', const Color(0xFF36343A)),
        onSurface: c('onSurface', const Color(0xFFE6E1E6)),
        onSurfaceVariant: c('onSurfaceVariant', const Color(0xFFCAC4CD)),
        outline: c('outline', const Color(0xFF948F99)),
        outlineVariant: c('outlineVariant', const Color(0xFF49454F)),
        inverseSurface: c('inverseSurface', const Color(0xFFE6E1E6)),
        inversePrimary: c('inversePrimary', const Color(0xFF00619F)),
      );
    }
  }

  static ArchiveFile _emptyFile() =>
      ArchiveFile('__empty__', 0, Uint8List(0));
}

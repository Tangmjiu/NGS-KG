import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// 已加载的主题包数据
class LoadedTheme {
  final String name;
  final String author;
  final int version;
  final Color lightPrimary;
  final Color darkPrimary;
  final Map<String, String> assetFiles; // key: asset id → file path in app dir
  final String id; // 唯一标识（文件名 hash）

  const LoadedTheme({
    required this.name,
    required this.author,
    required this.version,
    required this.lightPrimary,
    required this.darkPrimary,
    required this.assetFiles,
    required this.id,
  });
}

/// manifest.json 定义
class _Manifest {
  final String name;
  final String author;
  final int version;
  final Map<String, String>? colors;
  final Map<String, String>? assets;

  const _Manifest({
    required this.name,
    required this.author,
    required this.version,
    this.colors,
    this.assets,
  });

  factory _Manifest.fromJson(Map<String, dynamic> json) {
    return _Manifest(
      name: json['name'] as String? ?? '未命名主题',
      author: json['author'] as String? ?? '未知作者',
      version: json['version'] as int? ?? 1,
      colors: json['colors'] != null
          ? Map<String, String>.from(json['colors'] as Map)
          : null,
      assets: json['assets'] != null
          ? Map<String, String>.from(json['assets'] as Map)
          : null,
    );
  }
}

/// ZIP 主题导入引擎
///
/// 处理：
/// 1. 用户选择 ZIP 文件
/// 2. 解压、验证 manifest.json
/// 3. 提取资源文件到应用私有目录
/// 4. 返回 LoadedTheme 供 ThemeProvider 使用
class ThemeLoader {
  static const _themesPrefsKey = 'imported_themes';

  // ─── 公开方法 ───

  /// 从文件选择器导入 ZIP 主题包
  static Future<LoadedTheme?> importFromPicker() async {
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

      return _parseZip(bytes, file.name);
    } catch (e, s) {
      Log.e('ThemeLoader', 'import error', e, s);
      return null;
    }
  }

  /// 从字节数据解析 ZIP 主题包
  static Future<LoadedTheme?> _parseZip(List<int> bytes, String fileName) async {
    // 解压
    final archive = ZipDecoder().decodeBytes(bytes);
    if (archive.isEmpty) {
      Log.w('ThemeLoader', 'empty zip: $fileName');
      return null;
    }

    // 查找 manifest.json
    final manifestFile = archive.files.firstWhere(
      (f) => f.name == 'manifest.json' && !f.isFile,
      orElse: () => _emptyFile(),
    );
    if (!manifestFile.isFile) {
      Log.w('ThemeLoader', 'manifest.json not found in $fileName');
      return null;
    }

    // 解析 manifest
    final manifestJson = jsonDecode(
      utf8.decode(manifestFile.content),
    ) as Map<String, dynamic>;
    final manifest = _Manifest.fromJson(manifestJson);

    // 解析颜色
    final lightPrimary = _parseColor(
      manifest.colors?['light_primary'],
      const Color(0xFF2CA1F4),
    );
    final darkPrimary = _parseColor(
      manifest.colors?['dark_primary'],
      const Color(0xFF5BB8F8),
    );

    // 提取资源文件到应用目录
    final appDir = await _getThemeDir(_themeId(fileName));
    final assetFiles = <String, String>{};

    // 定义需要提取的资源
    const assetKeys = [
      'sthiswrong', 'codecrash', 'loading', 'ban', 'supportme', 'icon',
    ];

    for (final key in assetKeys) {
      final zipPath = manifest.assets?[key];
      if (zipPath == null || zipPath.isEmpty) continue;

      final zipEntry = archive.files.firstWhere(
        (f) => f.name == zipPath && !f.isFile,
        orElse: () => _emptyFile(),
      );
      if (!zipEntry.isFile) continue;

      final ext = zipPath.contains('.') ? '.${zipPath.split('.').last}' : '.png';
      final destName = '$key$ext';
      final destPath = '${appDir.path}/$destName';
      await File(destPath).writeAsBytes(zipEntry.content);
      assetFiles[key] = destPath;
    }

    // 记录已导入
    await _recordImported(_themeId(fileName));

    return LoadedTheme(
      name: manifest.name,
      author: manifest.author,
      version: manifest.version,
      lightPrimary: lightPrimary,
      darkPrimary: darkPrimary,
      assetFiles: assetFiles,
      id: _themeId(fileName),
    );
  }

  // ─── 已导入主题管理 ───

  /// 获取所有已导入的主题 ID 列表（持久化）
  static Future<List<String>> getImportedThemeIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_themesPrefsKey) ?? [];
  }

  /// 记录已导入的主题 ID
  static Future<void> _recordImported(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_themesPrefsKey) ?? [];
    if (!list.contains(id)) {
      list.add(id);
      await prefs.setStringList(_themesPrefsKey, list);
    }
  }

  /// 删除已导入的主题
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
    // 用文件名（不含 .zip）作为 ID
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

  static Color _parseColor(String? hex, Color defaultColor) {
    if (hex == null || hex.isEmpty) return defaultColor;
    final h = hex.replaceFirst('#', '');
    final val = int.tryParse(h, radix: 16);
    if (val == null) return defaultColor;
    return Color(0xFF000000 | val); // 忽略 alpha，固定 FF
  }

  static ArchiveFile _emptyFile() =>
      ArchiveFile('__empty__', 0, Uint8List(0));
}

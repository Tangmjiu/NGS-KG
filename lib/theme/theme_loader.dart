// SPDX-License-Identifier: MIT
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/theme_pack.dart';
import '../utils/logger.dart';

/// 主题安装与磁盘资源存储。清单格式由 ThemePack 的适配边界统一解析。
abstract final class ThemeLoader {
  static const _themesPrefsKey = 'imported_themes_v2';
  static Future<void> _pendingMutation = Future.value();

  static Future<T> _mutate<T>(Future<T> Function() operation) {
    final result = _pendingMutation.then((_) => operation());
    _pendingMutation =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static Future<ThemePack?> importFromPicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.first;
      final bytes = file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      return bytes == null ? null : parseZipBytes(bytes, file.name);
    } catch (error, stack) {
      Log.e('ThemeLoader', 'Import failed', error, stack);
      return null;
    }
  }

  static Future<ThemePack?> parseZipBytes(List<int> bytes, String fileName,
          {Directory? themesDirectory}) =>
      _mutate(
          () => _installZip(bytes, fileName, themesDirectory: themesDirectory));

  static Future<ThemePack?> _installZip(List<int> bytes, String fileName,
      {Directory? themesDirectory}) async {
    Directory? revision;
    File? pendingManifest;
    SharedPreferences? prefs;
    String? newInventoryId;
    var committed = false;
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      ArchiveFile? find(String name) {
        for (final entry in archive.files) {
          if (entry.isFile && entry.name == name) return entry;
        }
        return null;
      }

      final manifest = find('manifest.json');
      if (manifest == null) return null;
      final source = jsonDecode(utf8.decode(manifest.content));
      if (source is! Map<String, dynamic>) return null;
      final version = source['version'] ?? 1;
      if (version is! int || version < 1 || version > 3) return null;
      final id = path
          .basename(fileName.replaceAll('\\', '/'))
          .replaceFirst(RegExp(r'\.zip$', caseSensitive: false), '');
      if (!_validId(id) ||
          const ['ngs_default', 'ngs_nagisa', 'md3_default'].contains(id)) {
        return null;
      }
      final parsed =
          ThemePack.fromJson({...source, 'id': id, 'isBuiltIn': false});
      final directory = await _directory(id, themesDirectory: themesDirectory);
      final revisions = Directory(path.join(directory.path, 'revisions'));
      for (final destination in [directory.path, revisions.path]) {
        if (await FileSystemEntity.type(destination, followLinks: false) ==
            FileSystemEntityType.link) {
          throw FileSystemException(
              'Theme directory cannot be a link', destination);
        }
      }
      await revisions.create(recursive: true);
      final currentRevision = await revisions.createTemp('revision_');
      revision = currentRevision;
      final revisionName = path.basename(currentRevision.path);
      final data = parsed.toJson();

      Future<String?> extract(String? archivePath, String destination) async {
        if (archivePath == null || archivePath.isEmpty) return null;
        final entry = find(archivePath);
        if (entry == null) return null;
        final file = File(path.join(currentRevision.path, destination));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(entry.content, flush: true);
        return path.join('revisions', revisionName, destination);
      }

      final assets = <String, String>{};
      for (final entry in (parsed.assetFiles ?? <String, String>{}).entries) {
        if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(entry.key)) continue;
        final extension = path.extension(entry.value);
        final relative =
            await extract(entry.value, 'images/${entry.key}$extension');
        if (relative != null) assets[entry.key] = relative;
      }
      data['assetFiles'] = assets;
      data['previewPath'] = await extract('preview.png', 'preview.png');
      final wallpaper = parsed.playerBgPath;
      data['playerBgPath'] = await extract(
          wallpaper, 'images/player_bg${path.extension(wallpaper ?? '.png')}');
      final fonts = parsed.fontWeightFiles;
      if (fonts != null) {
        final files = <String, String>{};
        for (final entry in fonts.toJson().entries) {
          final sourcePath = entry.value as String?;
          final relative = await extract(sourcePath,
              'fonts/${entry.key}${path.extension(sourcePath ?? '.ttf')}');
          if (relative != null) files[entry.key] = relative;
        }
        data['fontWeightFiles'] = files;
      }
      final installedPack = _resolvePack(data, id, directory);
      final stagedManifest =
          File(path.join(directory.path, '.$revisionName.json'));
      pendingManifest = stagedManifest;
      await stagedManifest.writeAsString(jsonEncode(data), flush: true);

      // 清单是提交点；在此之前只写新目录，现用资源及清单保持完整。
      final preferences = await SharedPreferences.getInstance();
      prefs = preferences;
      final installed =
          preferences.getStringList(_themesPrefsKey) ?? <String>[];
      if (!installed.contains(id)) {
        newInventoryId = id;
        if (!await preferences
            .setStringList(_themesPrefsKey, [...installed, id])) {
          throw StateError('Cannot record imported theme');
        }
      }
      await stagedManifest.rename(path.join(directory.path, 'manifest.json'));
      committed = true;
      try {
        await _cleanOldResources(directory, currentRevision);
      } catch (error, stack) {
        // 新主题已经提交，清理失败不回滚或删除有效的新资源。
        Log.w('ThemeLoader', 'Cannot remove unused theme resources', error,
            stack);
      }
      return installedPack;
    } catch (error, stack) {
      Log.e('ThemeLoader', 'Invalid theme archive: $fileName', error, stack);
      return null;
    } finally {
      if (!committed) {
        Future<void> rollback(Future<void> Function() action) async {
          try {
            await action();
          } catch (error, stack) {
            Log.w('ThemeLoader', 'Cannot clean incomplete theme installation',
                error, stack);
          }
        }

        await rollback(() async {
          if (pendingManifest != null && await pendingManifest.exists()) {
            await pendingManifest.delete();
          }
        });
        await rollback(() async {
          if (revision != null && await revision.exists()) {
            await revision.delete(recursive: true);
          }
        });
        await rollback(() async {
          if (newInventoryId != null && prefs != null) {
            final installed =
                prefs.getStringList(_themesPrefsKey) ?? <String>[];
            await prefs.setStringList(_themesPrefsKey,
                installed.where((id) => id != newInventoryId).toList());
          }
        });
      }
    }
  }

  static Future<void> _cleanOldResources(
      Directory directory, Directory revision) async {
    final revisionsPath = path.dirname(revision.path);
    await for (final entry in directory.list(followLinks: false)) {
      if (entry.path == path.join(directory.path, 'manifest.json')) continue;
      if (entry.path == revisionsPath) {
        await for (final previous
            in Directory(revisionsPath).list(followLinks: false)) {
          if (previous.path != revision.path) {
            await previous.delete(recursive: true);
          }
        }
      } else {
        // 只清理此主题的安装目录，不追随旧绝对路径或目录符号链接。
        await entry.delete(recursive: true);
      }
    }
  }

  static Future<List<String>> getImportedThemeIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_themesPrefsKey) ?? [];
  }

  static Future<ThemePack?> loadPackFromDisk(String id,
      {Directory? themesDirectory}) async {
    try {
      if (!_validId(id)) return null;
      final directory = await _directory(id, themesDirectory: themesDirectory);
      final manifest = File(path.join(directory.path, 'manifest.json'));
      if (!await manifest.exists()) return null;
      final source = jsonDecode(await manifest.readAsString());
      if (source is! Map<String, dynamic>) return null;
      return _resolvePack(source, id, directory);
    } catch (error, stack) {
      Log.e('ThemeLoader', 'Cannot restore theme $id', error, stack);
      return null;
    }
  }

  static ThemePack _resolvePack(
      Map<String, dynamic> source, String id, Directory directory) {
    final pack = ThemePack.fromJson({...source, 'id': id, 'isBuiltIn': false});
    final data = pack.toJson();
    String? resolve(String? value) {
      if (value == null || value.isEmpty) return null;
      if (value.startsWith('assets/') ||
          path.isAbsolute(value) ||
          RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value)) {
        return value;
      }
      final result = path.normalize(path.join(directory.path, value));
      return path.isWithin(directory.path, result) ? result : null;
    }

    data['assetFiles'] = {
      for (final entry in (pack.assetFiles ?? <String, String>{}).entries)
        if (resolve(entry.value) != null) entry.key: resolve(entry.value),
    };
    data['previewPath'] = resolve(pack.previewPath);
    data['playerBgPath'] = resolve(pack.playerBgPath);
    if (pack.fontWeightFiles != null) {
      data['fontWeightFiles'] = pack.fontWeightFiles!
          .toJson()
          .map((key, value) => MapEntry(key, resolve(value as String?)));
    }
    return ThemePack.fromJson(data);
  }

  static Future<void> deleteTheme(String id, {Directory? themesDirectory}) =>
      _mutate(() async {
        if (!_validId(id)) return;
        final directory =
            await _directory(id, themesDirectory: themesDirectory);
        if (await directory.exists()) await directory.delete(recursive: true);
        final prefs = await SharedPreferences.getInstance();
        final installed = prefs.getStringList(_themesPrefsKey) ?? <String>[];
        await prefs.setStringList(
            _themesPrefsKey, installed.where((entry) => entry != id).toList());
      });

  static bool _validId(String id) =>
      id.isNotEmpty &&
      id != '.' &&
      id != '..' &&
      !id.contains('/') &&
      !id.contains('\\');

  static Future<Directory> _directory(String id,
      {Directory? themesDirectory}) async {
    final root = themesDirectory ??
        Directory(path.join(
            (await getApplicationDocumentsDirectory()).path, 'themes'));
    return Directory(path.join(root.path, id));
  }
}

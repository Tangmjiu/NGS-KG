import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/theme_market_listing.dart';
import '../models/theme_pack.dart';
import '../theme/theme_loader.dart';
import '../services/cache_service.dart';
import '../utils/logger.dart';

/// 主题市场服务
///
/// 负责：
/// 1. 从 GitHub raw 拉取 registry.json（带缓存）
/// 2. 从 GitHub Release 下载 ZIP
/// 3. 通过 ThemeLoader 解析并安装
class MarketService {
  static const _registryUrl =
      'https://raw.githubusercontent.com/Tangmjiu/ngs-kg-themes/main/registry.json';
  static const _cacheKey = 'market_registry';
  static const _cacheTtl = Duration(hours: 1);
  static const _installedPrefsKey = 'market_installed_themes';

  // ─── 注册表 ───

  /// 获取市场列表（优先走缓存，后台静默刷新）
  static Future<List<ThemeMarketListing>> fetchRegistry() async {
    // 先读缓存
    final cached = await CacheService.instance.getJson(_cacheKey);
    if (cached != null) {
      return _parseRegistry(cached);
    }

    // 拉取远程
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'User-Agent': 'NGS-KG+'},
      ));
      final res = await dio.get<String>(_registryUrl);
      final raw = res.data;
      if (raw == null) return [];
      final data = jsonDecode(raw) as Map<String, dynamic>;
      await CacheService.instance.putJson(_cacheKey, data, ttl: _cacheTtl);
      return _parseRegistry(data);
    } catch (e, s) {
      Log.e('MarketService', 'fetchRegistry failed', e, s);
      return [];
    }
  }

  /// 强制刷新注册表（下拉刷新时调用）
  static Future<List<ThemeMarketListing>> refreshRegistry() async {
    await CacheService.instance.remove(_cacheKey);
    return fetchRegistry();
  }

  /// 解析 registry.json 结构
  static List<ThemeMarketListing> _parseRegistry(Map<String, dynamic> data) {
    final themes = data['themes'] as List<dynamic>? ?? [];
    return themes
        .map((e) => ThemeMarketListing.fromJson(e as Map<String, dynamic>))
        .where((t) => t.id.isNotEmpty)
        .toList();
  }

  // ─── 下载与安装 ───

  /// 下载主题 ZIP 字节
  static Future<Uint8List?> downloadTheme(String downloadUrl) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
        headers: {'User-Agent': 'NGS-KG+'},
      ));
      final res = await dio.get<List<int>>(
        downloadUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      if (res.data == null || res.data!.isEmpty) return null;
      return Uint8List.fromList(res.data!);
    } catch (e, s) {
      Log.e('MarketService', 'downloadTheme failed', e, s);
      return null;
    }
  }

  /// 安装下载的 ZIP 字节 → 返回 ThemePack（null = 失败）
  static Future<ThemePack?> installTheme(
      Uint8List bytes, String fileName) async {
    try {
      final pack = await ThemeLoader.parseZipBytes(bytes, fileName);
      if (pack == null) return null;
      await _recordInstalled(pack.id);
      return pack;
    } catch (e, s) {
      Log.e('MarketService', 'installTheme failed', e, s);
      return null;
    }
  }

  // ─── 已安装管理 ───

  /// 检查主题是否已安装
  static Future<bool> isInstalled(String themeId) async {
    final installed = await getInstalledIds();
    return installed.contains(themeId);
  }

  /// 获取所有已安装的市场主题 ID
  static Future<Set<String>> getInstalledIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_installedPrefsKey)?.toSet() ?? {};
  }

  static Future<void> _recordInstalled(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_installedPrefsKey) ?? [];
    if (!list.contains(id)) {
      list.add(id);
      await prefs.setStringList(_installedPrefsKey, list);
    }
  }

  /// 卸载主题（仅清除市场记录，文件删除由 ThemeLoader.deleteTheme 负责）
  static Future<void> uninstallTheme(String themeId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_installedPrefsKey) ?? [];
    list.remove(themeId);
    await prefs.setStringList(_installedPrefsKey, list);
  }
}

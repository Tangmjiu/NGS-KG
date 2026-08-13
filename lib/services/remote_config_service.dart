// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// 远程配置服务
///
/// 用于在不暴露真实 API IP 的情况下，动态下发当前可用的 API base URL。
/// 启动时优先拉取远程配置，失败则使用本地缓存或默认域名。
///
/// 远程配置格式示例：
/// ```json
/// {
///   "api_base": "http://156.239.227.141:4000",
///   "fallback_base": "https://kugouapi.mjiutang.top",
///   "updated_at": 1756464000
/// }
/// ```
class RemoteConfigService {
  static const String _cacheKey = 'remote_api_base';
  static const String _cacheTimeKey = 'remote_api_base_fetched_at';

  /// 远程配置文件地址
  ///
  /// 该地址只返回配置，不包含服务器 IP。当前托管在 Cloudflare 代理后的二级域名，
  /// 用于抗 DNS 污染 / Clash TUN fake-ip 场景。
  static const String defaultRemoteUrl =
      'https://cfg.mjiutang.top/ngskg-config.json';

  /// 缓存有效期
  static const Duration cacheTtl = Duration(hours: 6);

  static final RemoteConfigService _instance = RemoteConfigService._();
  static RemoteConfigService get instance => _instance;

  String? _cachedBaseUrl;
  DateTime? _cachedAt;

  RemoteConfigService._();

  /// 当前缓存中的 API base URL（可能为空）
  String? get cachedBaseUrl => _cachedBaseUrl;

  /// 同步初始化：从 SharedPreferences 加载缓存
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedBaseUrl = prefs.getString(_cacheKey);
      final cachedTime = prefs.getInt(_cacheTimeKey);
      if (cachedTime != null) {
        _cachedAt = DateTime.fromMillisecondsSinceEpoch(cachedTime);
      }
      Log.i('RemoteConfig', '缓存 API base: $_cachedBaseUrl');
    } catch (e) {
      Log.w('RemoteConfig', '加载缓存失败', e);
    }
  }

  /// 从远程拉取最新配置
  ///
  /// [remoteUrl] 远程配置 URL，默认使用 [defaultRemoteUrl]。
  /// 返回拉取到的 api_base；失败返回 null，调用方应使用 fallback。
  Future<String?> fetch({String? remoteUrl}) async {
    final url = remoteUrl ?? defaultRemoteUrl;
    if (url == defaultRemoteUrl) {
      Log.w('RemoteConfig', 'remoteUrl 仍是占位符，跳过拉取');
      return null;
    }

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5)
        ..idleTimeout = const Duration(seconds: 3);

      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        Log.w('RemoteConfig', '远程配置返回 ${response.statusCode}');
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final baseUrl = data['api_base'] as String?;

      if (baseUrl != null && baseUrl.isNotEmpty) {
        await _setCachedBaseUrl(baseUrl);
        Log.i('RemoteConfig', '远程配置拉取成功: $baseUrl');
        return baseUrl;
      }

      Log.w('RemoteConfig', '远程配置缺少 api_base 字段');
      return null;
    } catch (e) {
      Log.w('RemoteConfig', '拉取远程配置失败', e);
      return null;
    }
  }

  /// 如果缓存未过期，返回缓存的 API base URL
  String? getValidCachedBaseUrl() {
    if (_cachedBaseUrl == null || _cachedBaseUrl!.isEmpty) return null;
    if (_cachedAt == null) return _cachedBaseUrl;
    if (DateTime.now().difference(_cachedAt!) > cacheTtl) return null;
    return _cachedBaseUrl;
  }

  /// 清空缓存（例如用户切换回域名模式时）
  Future<void> clearCache() async {
    _cachedBaseUrl = null;
    _cachedAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimeKey);
  }

  Future<void> _setCachedBaseUrl(String url) async {
    _cachedBaseUrl = url;
    _cachedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, url);
    await prefs.setInt(_cacheTimeKey, _cachedAt!.millisecondsSinceEpoch);
  }
}

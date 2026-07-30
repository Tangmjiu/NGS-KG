import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import 'remote_config_service.dart';

/// API 地址动态配置
///
/// 三种来源（优先级从高到低）：
///   1. 远程配置下发（RemoteConfigService 缓存）— 不暴露真实 IP
///   2. mjiutang — 内置域名路线（Cloudflare 已关闭代理，直接用域名）
///   3. custom  — 用户自定义地址
///
/// 注：原中国内地路线（111.170.14.52）已失效，保留枚举仅兼容旧版本持久化数据。
class ApiConfig {
  static ApiConfig? _instance;

  static const String _modeKey = 'api_mode';
  static const String _routeKey = 'mjiutang_route';
  static const String _customUrlKey = 'api_base_url';

  static const String modeMjiutang = 'mjiutang';
  static const String modeCustom = 'custom';
  static const String routeCloudflare = 'cloudflare';

  /// 已弃用：仅用于兼容旧版本 SharedPreferences 中的持久化值
  static const String routeChina = 'china';

  /// 默认域名路线（Cloudflare 代理已关闭，直接解析到香港服务器）
  static const String cloudflareUrl = 'https://kugouapi.mjiutang.top';

  String _cachedUrl = '';

  ApiConfig._();

  static ApiConfig get instance {
    _instance ??= ApiConfig._();
    return _instance!;
  }

  // ─── 模式 / 路线持久化 ───

  Future<String> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modeKey) ?? modeMjiutang;
  }

  Future<void> setMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode);
    _cachedUrl = '';
  }

  Future<String> getMjiutangRoute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_routeKey) ?? routeCloudflare;
  }

  Future<void> setMjiutangRoute(String route) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_routeKey, route);
    _cachedUrl = '';
  }

  /// 根据当前模式计算实际 URL
  ///
  /// 优先级：
  ///   1. 远程配置缓存中的有效 api_base
  ///   2. 自定义模式下的用户地址
  ///   3. 默认域名路线
  Future<String> getBaseUrl() async {
    if (_cachedUrl.isNotEmpty) return _cachedUrl;

    // 1. 远程配置缓存
    final remoteCached = RemoteConfigService.instance.getValidCachedBaseUrl();
    if (remoteCached != null && remoteCached.isNotEmpty) {
      _cachedUrl = _normalizeUrl(remoteCached);
      return _cachedUrl;
    }

    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_modeKey) ?? modeMjiutang;

    // 2. 用户自定义地址
    if (mode == modeCustom) {
      final custom = prefs.getString(_customUrlKey);
      if (custom != null && custom.isNotEmpty) {
        _cachedUrl = _normalizeUrl(custom);
        return _cachedUrl;
      }
    }

    // 3. 默认域名路线（旧版 routeChina 也统一回退到域名）
    final route = prefs.getString(_routeKey) ?? routeCloudflare;
    _cachedUrl = route == routeCloudflare ? cloudflareUrl : cloudflareUrl;
    return _cachedUrl;
  }

  /// 后台探测 API 可用性
  ///
  /// 原内地路线已失效，只探测域名路线。若域名不通且远程配置未启用，
  /// 用户可手动切换到自定义 IP 模式。
  Future<void> detectBestRoute() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_modeKey) == modeCustom) return;

    Log.i('ApiConfig', '开始探测 API 路线...');
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 1500)
      ..idleTimeout = const Duration(seconds: 2);

    try {
      final request = await client.getUrl(Uri.parse(cloudflareUrl));
      final response = await request.close();
      if (response.statusCode >= 200 && response.statusCode < 400) {
        Log.i('ApiConfig', '域名路线可用, 状态码: ${response.statusCode}');
        await setMjiutangRoute(routeCloudflare);
        return;
      }
    } catch (e) {
      Log.w('ApiConfig', '域名路线探测失败: $e');
    }

    Log.e('ApiConfig', '域名路线不可用，请检查网络，或在设置中切换到自定义 IP。');
  }

  String get baseUrlSync => _cachedUrl.isNotEmpty ? _cachedUrl : cloudflareUrl;

  /// 自定义模式下保存用户地址
  Future<void> setCustomUrl(String url) async {
    final normalized = _normalizeUrl(url);
    _cachedUrl = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customUrlKey, normalized);
    Log.i('ApiConfig', '自定义 API 地址已保存: $normalized');
  }

  /// 获取自定义模式下已保存的地址
  Future<String?> getCustomUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customUrlKey);
  }

  /// 重置为默认（mjiutang + cloudflare）
  Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_modeKey);
    await prefs.remove(_routeKey);
    await prefs.remove(_customUrlKey);
    _cachedUrl = '';
    Log.i('ApiConfig', '已重置为默认 mjiutang/Cloudflare');
  }

  // ─── 工具 ───

  String _normalizeUrl(String url) {
    String trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'http://$trimmed';
    }
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static String? validateUrl(String url) {
    if (url.trim().isEmpty) return '地址不能为空';
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return '请输入完整的 http(s):// 地址';
    if (!uri.hasScheme || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return '仅支持 http:// 或 https://';
    }
    if (!uri.hasAuthority || uri.host.isEmpty) return '请输入有效的服务器地址';
    return null;
  }
}

import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// API 地址动态配置
///
/// 两种模式：
///   1. mjiutang — 内置两个路线（Cloudflare 海外 / 中国内地）
///   2. custom  — 用户自定义地址
class ApiConfig {
  static ApiConfig? _instance;

  static const String _modeKey = 'api_mode';
  static const String _routeKey = 'mjiutang_route';
  static const String _customUrlKey = 'api_base_url';

  static const String modeMjiutang = 'mjiutang';
  static const String modeCustom = 'custom';
  static const String routeCloudflare = 'cloudflare';
  static const String routeChina = 'china';

  static const String cloudflareUrl = 'https://kugouapi.mjiutang.top';
  static const String chinaUrl = 'http://111.170.14.52:42980';

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
    return prefs.getString(_routeKey) ?? routeChina;
  }

  Future<void> setMjiutangRoute(String route) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_routeKey, route);
    _cachedUrl = '';
  }

  /// 根据当前模式计算实际 URL
  Future<String> getBaseUrl() async {
    if (_cachedUrl.isNotEmpty) return _cachedUrl;

    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_modeKey) ?? modeMjiutang;

    if (mode == modeCustom) {
      final custom = prefs.getString(_customUrlKey);
      if (custom != null && custom.isNotEmpty) {
        _cachedUrl = _normalizeUrl(custom);
        return _cachedUrl;
      }
    }

    final route = prefs.getString(_routeKey) ?? routeChina;
    _cachedUrl = route == routeCloudflare ? cloudflareUrl : chinaUrl;
    return _cachedUrl;
  }

  String get baseUrlSync => _cachedUrl.isNotEmpty ? _cachedUrl : chinaUrl;

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

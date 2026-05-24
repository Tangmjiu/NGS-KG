import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// API 地址动态配置
///
/// 优先链（仿 MoeKoeMusic）：
///   1. SharedPreferences 用户自定义地址
///   2. 编译期默认地址
///
/// 未来可扩展：
///   - 环境变量（dart-define）
///   - 直接网关模式（搭配 KugouSigner 直连 gateway.kugou.com）
class ApiConfig {
  static ApiConfig? _instance;

  static const String _prefsKey = 'api_base_url';

  /// 默认地址 — 可被 SharedPreferences 覆盖
  static const String defaultBaseUrl = 'http://111.170.14.52:42980';

  /// 酷狗官方网关地址（直连模式）
  static const String kugouGatewayUrl = 'https://gateway.kugou.com';

  String _cachedUrl = '';

  ApiConfig._();

  static ApiConfig get instance {
    _instance ??= ApiConfig._();
    return _instance!;
  }

  /// 获取当前 API 基地址
  ///
  /// 优先返回持久化的用户自定义值，若无则返回默认值。
  Future<String> getBaseUrl() async {
    if (_cachedUrl.isNotEmpty) return _cachedUrl;

    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getString(_prefsKey);
    if (custom != null && custom.isNotEmpty) {
      _cachedUrl = _normalizeUrl(custom);
      return _cachedUrl;
    }

    _cachedUrl = defaultBaseUrl;
    return _cachedUrl;
  }

  /// 同步获取当前缓存的值（可能落后于 SharedPreferences）
  String get baseUrlSync => _cachedUrl.isNotEmpty ? _cachedUrl : defaultBaseUrl;

  /// 设置 API 基地址并持久化
  Future<void> setBaseUrl(String url) async {
    final normalized = _normalizeUrl(url);
    _cachedUrl = normalized;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, normalized);

    Log.i('ApiConfig', 'API 地址已切换为: $normalized');
  }

  /// 重置为默认地址
  Future<void> resetToDefault() async {
    _cachedUrl = defaultBaseUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  /// 获取当前使用的模式标签（用于 UI 显示）
  Future<String> getModeLabel() async {
    final url = await getBaseUrl();
    if (url == defaultBaseUrl) return '默认';
    if (url.contains('gateway.kugou.com')) return '直连网关';
    return '自定义';
  }

  /// 判断是否使用了默认地址
  Future<bool> get isDefault async {
    final url = await getBaseUrl();
    return url == defaultBaseUrl;
  }

  // ─── 私有工具 ───

  String _normalizeUrl(String url) {
    String trimmed = url.trim();
    // 确保以 http(s):// 开头
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'http://$trimmed';
    }
    // 移除末尾斜杠
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  /// 验证 URL 格式
  static String? validateUrl(String url) {
    if (url.trim().isEmpty) return '地址不能为空';
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return '请输入完整的 http(s):// 地址';
    if (!uri.hasScheme || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return '仅支持 http:// 或 https://';
    }
    if (!uri.hasAuthority || uri.host.isEmpty) return '请输入有效的服务器地址';
    return null; // 有效
  }
}

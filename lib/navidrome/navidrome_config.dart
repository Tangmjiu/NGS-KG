import 'package:shared_preferences/shared_preferences.dart';

class NavidromeConfig {
  static NavidromeConfig? _instance;

  static const _urlKey = 'navidrome_url';
  static const _usernameKey = 'navidrome_username';
  static const _passwordKey = 'navidrome_password';

  NavidromeConfig._();

  static NavidromeConfig get instance {
    _instance ??= NavidromeConfig._();
    return _instance!;
  }

  Future<String?> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_urlKey);
  }

  Future<void> setServerUrl(String url) async {
    final normalized = _normalizeUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, normalized);
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  Future<void> setUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
  }

  Future<String?> getPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_passwordKey);
  }

  Future<void> setPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_passwordKey, password);
  }

  Future<bool> hasConfig() async {
    final url = await getServerUrl();
    return url != null && url.isNotEmpty;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_urlKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_passwordKey);
  }

  /// Normalize URL: add http:// if missing, remove trailing slash.
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

  /// Validate a URL. Returns null if valid, error string if invalid.
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

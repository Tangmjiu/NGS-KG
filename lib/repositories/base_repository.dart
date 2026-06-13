import 'package:dio/dio.dart';
import '../services/api_client.dart';

abstract class BaseRepository {
  final ApiClient client;

  BaseRepository(this.client);

  /// 发起 GET 请求，认证信息由 ApiClient 的 _AuthInterceptor 自动注入 Authorization 头。
  /// [withAuth] = false 时阻止拦截器注入认证信息（设备注册等接口使用）。
  /// [withCookie] = true 时将 cookie 认证信息作为 URL 查询参数附加（搜索/歌单等接口需要）。
  /// [silent] = true 时请求失败不弹错误弹窗（用于静默降级重试）。
  Future<Map<String, dynamic>> get(String path,
      {Map<String, dynamic>? params, bool withAuth = true,
      bool withCookie = false, bool silent = false}) async {
    if (withCookie) {
      params ??= <String, dynamic>{};
      if (!params.containsKey('cookie')) {
        final cookie = await _getCookieString();
        if (cookie != null) params['cookie'] = cookie;
      }
    }
    final extra = <String, dynamic>{};
    if (!withAuth) extra['noAuth'] = true;
    if (silent) extra['silent'] = true;
    final options = extra.isNotEmpty ? Options(extra: extra) : null;
    final res = await client.get(path, params: params, options: options);
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> cachedGet(String path,
      {Map<String, dynamic>? params, bool withAuth = true,
      Duration? ttl}) async {
    final res = await client.getCached(path, params: params,
        ttl: ttl ?? const Duration(hours: 2),
        withAuth: withAuth);
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }

  /// 获取 cookie 字符串，用于需要 cookie 查询参数的接口（搜索、歌单等）。
  Future<String?> _getCookieString() async {
    try {
      return await client.getCookieString();
    } catch (_) {
      return null;
    }
  }
}

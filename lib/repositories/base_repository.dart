import 'package:dio/dio.dart';
import '../services/api_client.dart';

abstract class BaseRepository {
  final ApiClient client;

  BaseRepository(this.client);

  /// 发起 GET 请求，认证信息由 ApiClient 的 _AuthInterceptor 自动注入 Authorization 头。
  /// [withAuth] = false 时阻止拦截器注入认证信息（设备注册等接口使用）。
  Future<Map<String, dynamic>> get(String path,
      {Map<String, dynamic>? params, bool withAuth = true}) async {
    final options = withAuth ? null : Options(extra: {'noAuth': true});
    final res = await client.get(path, params: params, options: options);
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> cachedGet(String path,
      {Map<String, dynamic>? params, bool withAuth = true,
      Duration? ttl}) async {
    final res = await client.getCached(path, params: params,
        ttl: ttl ?? const Duration(hours: 2));
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }
}

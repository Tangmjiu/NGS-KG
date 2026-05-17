import 'package:dio/dio.dart';
import 'cache_service.dart';

class CacheInterceptor extends Interceptor {
  final CacheService _cache = CacheService.instance;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final ttl = options.extra['cache_ttl'] as Duration?;
    if (ttl == null) return handler.next(options);

    final key = _buildKey(options);
    final cached = await _cache.getJson(key);
    if (cached != null) {
      return handler.resolve(Response(
        requestOptions: options,
        data: cached,
        statusCode: 200,
      ));
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final ttl = response.requestOptions.extra['cache_ttl'] as Duration?;
    if (ttl == null) return handler.next(response);

    if (response.statusCode == 200 && response.data is Map) {
      final key = _buildKey(response.requestOptions);
      await _cache.putJson(key, response.data, ttl: ttl);
    }
    handler.next(response);
  }

  String _buildKey(RequestOptions options) {
    final buf = StringBuffer(options.uri.path);
    final params = Map<String, dynamic>.from(options.queryParameters);
    params.remove('cookie');
    params.remove('Cookie');
    final keys = params.keys.toList()..sort();
    for (final k in keys) {
      buf.write('|$k=${params[k]}');
    }
    return buf.toString();
  }
}

import '../services/api_client.dart';

abstract class BaseRepository {
  final ApiClient client;

  BaseRepository(this.client);

  Future<Map<String, dynamic>> get(String path,
      {Map<String, dynamic>? params, bool withAuth = true}) async {
    final p = Map<String, dynamic>.from(params ?? {});
    if (withAuth) {
      p['cookie'] = await client.getCookieString();
    }
    final res = await client.get(path, params: p);
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> cachedGet(String path,
      {Map<String, dynamic>? params, bool withAuth = true,
      Duration? ttl}) async {
    final p = Map<String, dynamic>.from(params ?? {});
    if (withAuth) {
      p['cookie'] = await client.getCookieString();
    }
    final res = await client.getCached(path, params: p,
        ttl: ttl ?? const Duration(hours: 2));
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }
}

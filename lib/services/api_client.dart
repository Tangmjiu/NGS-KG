import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import '../utils/constants.dart';
import 'api_exception.dart';
import 'api_config.dart';
import 'cache_interceptor.dart';
import 'device_service.dart';

/// 自动重试拦截器
class _RetryInterceptor extends Interceptor {
  static const int _maxRetries = 2;
  static const Duration _baseDelay = Duration(seconds: 1);

  const _RetryInterceptor();

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err)) {
      final retryCount = (err.requestOptions.extra['_retryCount'] as int?) ?? 0;
      if (retryCount < _maxRetries) {
        await Future.delayed(_baseDelay * (retryCount + 1));
        err.requestOptions.extra['_retryCount'] = retryCount + 1;
        try {
          final response = await Dio().fetch(err.requestOptions);
          handler.resolve(response);
          return;
        } catch (_) {
          handler.next(err);
          return;
        }
      }
    }
    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError;
  }
}

/// 认证拦截器（MoeKoeMusic 风格）
///
/// 在每个请求的 Authorization 头中注入：
///   token + userid + dfid + KUGOU_API_MID + KUGOU_API_GUID + KUGOU_API_DEV + KUGOU_API_MAC
///
/// KuGouMusicApi 代理服务器会解析此头部作为 Cookie 使用。
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    // noAuth 标记的请求跳过（设备注册等无需认证的请求）
    if (options.extra['noAuth'] == true) {
      return handler.next(options);
    }

    try {
      final device = await DeviceService.instance.getDeviceInfo();
      final token = ApiClient._authToken;
      final userId = ApiClient._authUserId;

      final parts = <String>[];
      if (token != null && token.isNotEmpty) parts.add('token=$token');
      if (userId != null && userId.isNotEmpty) parts.add('userid=$userId');
      if (device != null && device.isValid) {
        parts.add('dfid=${device.dfid}');
        if (device.mid.isNotEmpty) parts.add('KUGOU_API_MID=${device.mid}');
        if (device.guid.isNotEmpty) {
          parts.add('KUGOU_API_GUID=${device.guid}');
        }
        if (device.serverDev.isNotEmpty) {
          parts.add('KUGOU_API_DEV=${device.serverDev}');
        }
        if (device.mac.isNotEmpty) parts.add('KUGOU_API_MAC=${device.mac}');
      }

      if (parts.isNotEmpty) {
        options.headers['Authorization'] = parts.join(';');
      }
    } catch (_) {
      // 降级：无法获取设备信息时仍允许请求通过
    }

    handler.next(options);
  }
}

/// 动态 BaseUrl 拦截器
///
/// 每次请求时读取最新的 API 地址配置，实现运行时切换。
class _DynamicBaseUrlInterceptor extends Interceptor {
  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    // 如果请求已经明确指定了 baseUrl，不覆盖
    if (options.baseUrl.isNotEmpty &&
        options.extra['_baseUrlSet'] != true) {
      try {
        options.baseUrl = await ApiConfig.instance.getBaseUrl();
        options.extra['_baseUrlSet'] = true;
      } catch (_) {}
    }
    handler.next(options);
  }
}

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;
  late final CookieJar _cookieJar;

  /// 静态认证状态（由 AuthProvider 设置）
  static String? _authToken;
  static String? _authUserId;
  static String? _dfid;

  // ─── 静态认证管理 ───

  static void setAuth(String? token, String? userId) {
    _authToken = token;
    _authUserId = userId;
  }

  static void clearAuth() {
    _authToken = null;
    _authUserId = null;
  }

  static void setDfid(String? dfid) {
    _dfid = dfid;
  }

  static String? get dfid => _dfid;

  static String? get userId => _authUserId;

  // ─── 单例 ───

  ApiClient._() {
    _cookieJar = CookieJar();

    _dio = Dio(BaseOptions(
      // 初始 baseUrl — 会被 _DynamicBaseUrlInterceptor 在运行期覆盖
      baseUrl: ApiConfig.defaultBaseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {
        'User-Agent': AppConstants.userAgent,
      },
    ));

    // 拦截器链（顺序很重要）
    // 1. 动态 BaseUrl（最先执行，确保 baseUrl 正确）
    _dio.interceptors.add(_DynamicBaseUrlInterceptor());
    // 2. 认证头注入
    _dio.interceptors.add(_AuthInterceptor());
    // 3. 重试（网络异常）
    _dio.interceptors.add(const _RetryInterceptor());
    // 4. Cookie 管理（兼容旧 cookie 流程）
    _dio.interceptors.add(CookieManager(_cookieJar));
    // 5. 响应缓存
    _dio.interceptors.add(CacheInterceptor());
    // 6. 日志
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (o) {},
    ));
  }

  /// 重新构建 Dio 实例（API 地址变更时调用）
  ///
  /// 会保留认证状态和缓存，仅重建底层 HTTP 配置。
  void reinitialize() {
    _instance = null;
    _instance = ApiClient._();
    // 恢复静态状态
    if (_dfid != null && _dfid!.isNotEmpty) _dio.options.extra['_dfid'] = _dfid;
  }

  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  Dio get dio => _dio;

  // ─── HTTP 方法封装 ───

  Future<Response> get(String path, {Map<String, dynamic>? params, Options? options}) async {
    try {
      final response = await _dio.get(path, queryParameters: params, options: options);
      _checkNeedLogin(response.data);
      return response;
    } on DioException catch (e) {
      if (e.response?.statusCode == 200) {
        final data = e.response?.data;
        if (data is Map) _checkNeedLogin(data);
        return e.response!;
      }
      if (_isNetworkError(e)) throw NetworkErrorException.fromDio(e);
      rethrow;
    }
  }

  Future<Response> getCached(
    String path, {
    Map<String, dynamic>? params,
    Duration ttl = const Duration(hours: 2),
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: params,
        options: Options(extra: {'cache_ttl': ttl}),
      );
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw NetworkErrorException.fromDio(e);
      rethrow;
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw NetworkErrorException.fromDio(e);
      rethrow;
    }
  }

  // ─── Cookie 工具（向后兼容） ───

  /// 获取当前完整的 Cookie 字符串（含认证信息 + 设备指纹）
  ///
  /// 保留此方法以兼容现有通过 query param 传递 cookie 的代码路径。
  /// 新代码应优先使用 Authorization 头（由 _AuthInterceptor 自动注入）。
  Future<String> getCookieString() async {
    final uri = Uri.parse(await ApiConfig.instance.getBaseUrl());
    final cookies = await _cookieJar.loadForRequest(uri);
    final parts = <String>[];
    for (final c in cookies) {
      if (c.name.isNotEmpty && c.value.isNotEmpty) {
        parts.add('${c.name}=${c.value}');
      }
    }

    // 追加认证信息
    if (_authToken != null && _authToken!.isNotEmpty) {
      parts.add('token=$_authToken');
    }
    final uid = _authUserId;
    parts.add('userid=${(uid != null && uid.isNotEmpty) ? uid : 0}');

    // 追加设备信息
    try {
      final device = await DeviceService.instance.getDeviceInfo();
      if (device != null && device.isValid) {
        parts.add('dfid=${device.dfid}');
        if (device.mid.isNotEmpty) parts.add('KUGOU_API_MID=${device.mid}');
        if (device.guid.isNotEmpty) {
          parts.add('KUGOU_API_GUID=${device.guid}');
        }
      }
    } catch (_) {}

    return parts.join(';');
  }

  // ─── 连接测试 ───

  /// 测试 API 地址连通性
  ///
  /// 调用 /register/dev 端点检查服务器是否可用。
  /// 仿 MoeKoeMusic 的 testApiBaseUrl。
  static Future<Map<String, dynamic>> testConnection(String baseUrl) async {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ));
    try {
      final response = await dio.get('/register/dev');
      final data = response.data;
      if (data is Map) {
        final inner = data['data'] as Map<String, dynamic>? ?? data;
        final dfid = inner['dfid'] as String?;
        if (dfid != null && dfid.isNotEmpty) {
          return {'ok': true, 'dfid': dfid};
        }
        return {'ok': true, 'data': data};
      }
      return {'ok': false, 'error': 'invalid_response'};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  // ─── 私有 ───

  void _checkNeedLogin(dynamic data) {
    if (data is Map) {
      final status = data['status'] ?? data['code'];
      if (status == 20010 || status == '20010') {
        throw const NeedLoginException();
      }
    }
  }

  bool _isNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError;
  }
}

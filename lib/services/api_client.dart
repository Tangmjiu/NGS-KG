import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import '../utils/constants.dart';
import '../utils/error_dialog.dart';
import '../utils/logger.dart';
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

/// KuGouMusicApi 已知错误码 → 中文释义
const Map<Object, String> _kugouErrorMessages = {
  '152': '搜索需要登录认证',
  '20010': '登录已过期，请重新登录',
  '20028': '账户触发风控，请稍后在手机上滑动验证后再试',
  '20006': '操作频繁，请稍后重试',
  '31136': '接口请求参数错误，请检查参数',
};

/// KuGouMusicApi 已知 error_code → 简短标签
const Map<Object, String> _kugouErrorLabels = {
  '152': '缺少认证',
  '20010': '登录失效',
  '20028': '账户风控',
  '20006': '操作受限',
  '31136': '参数错误',
  152: '缺少认证',
  20010: '登录失效',
  20028: '账户风控',
  20006: '操作受限',
  31136: '参数错误',
};

/// 错误弹窗拦截器
///
/// 在 Dio 请求链最后捕获所有未处理的异常，弹出错误提示。
/// 排在最末尾，确保前面的拦截器（重试、缓存等）有机会先处理。
///
/// 如果请求的 extra 中标记了 `silent: true`，则跳过弹窗（仅日志），
/// 用于已知会失败但无需打扰用户的请求（如已失效的 banner 接口）。
class _ErrorDialogInterceptor extends Interceptor {
  /// 构造不带 host 的请求 URL（/path?key=val），隐藏 IP
  static String _requestUrl(RequestOptions opts) {
    final buf = StringBuffer(opts.path);
    final params = opts.queryParameters;
    if (params.isNotEmpty) {
      buf.write('?');
      bool first = true;
      params.forEach((k, v) {
        if (!first) buf.write('&');
        first = false;
        buf.write('$k=$v');
      });
    }
    return buf.toString();
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // 静默标记的请求跳过弹窗
    if (err.requestOptions.extra['silent'] == true) {
      Log.w('ApiClient',
          '静默错误: ${_requestUrl(err.requestOptions)} | ${err.message}');
      handler.next(err);
      return;
    }
    // 网络错误已被 RetryInterceptor 重试过，到达这里说明已耗尽重试
    final statusCode = err.response?.statusCode;
    final data = err.response?.data;
    final requestPath = _requestUrl(err.requestOptions);
    String message;
    String? codeStr;
    String? detail;
    bool showLogin = false;

    if (data is Map) {
      final apiCode = data['status'] ?? data['code'];
      final rawErrorCode = data['error_code'];
      final rawMsg = data['error'] as String? ??
          data['message'] as String? ??
          data['msg'] as String?;

      // 构建错误码显示字符串
      final parts = <String>[];
      if (statusCode != null) parts.add('HTTP $statusCode');
      if (rawErrorCode != null) parts.add('error_code=$rawErrorCode');
      if (apiCode != null && apiCode != rawErrorCode) {
        parts.add('API $apiCode');
      }
      codeStr = parts.isNotEmpty ? parts.join(' / ') : null;

      // 根据错误码选择中文提示
      final knownMsg =
          _kugouErrorMessages[apiCode] ?? _kugouErrorMessages[rawErrorCode];
      final label =
          _kugouErrorLabels[apiCode] ?? _kugouErrorLabels[rawErrorCode];

      if (knownMsg != null) {
        message = knownMsg;
        if (apiCode == 20010 ||
            apiCode == '20010' ||
            rawErrorCode == 20010 ||
            rawErrorCode == '20010') {
          showLogin = true;
          // 清除过期 token，后续请求不再携带
          ApiClient.clearAuth();
        }
      } else {
        message = rawMsg ?? '请求失败';
      }

      // 详细信息包含请求路径 + 原始响应
      final detailBuf = StringBuffer('请求路径: $requestPath');
      if (rawErrorCode != null) detailBuf.writeln('\n原始错误码: $rawErrorCode');
      if (rawMsg != null && rawMsg != message)
        detailBuf.writeln('\n原始消息: $rawMsg');
      detail = detailBuf.toString();

      // 日志 — 输出原始响应体便于调试
      final logLabel = label ??
          (statusCode != null && statusCode >= 500 ? '服务器错误' : 'API错误');
      Log.e(
          'ApiClient',
          '$logLabel $codeStr — $message | $requestPath | raw: ${jsonEncode(data)}',
          err);

      // 弹窗
      showErrorDialog(
        title: label ?? '错误',
        errorCode: codeStr,
        message: message,
        detail: detail,
        showLogin: showLogin,
      );
      handler.next(err);
      return;
    }

    // 非 Map 响应体（纯 HTTP 错误或网络错误）
    if (statusCode != null) {
      codeStr = 'HTTP $statusCode';
      message = statusCode >= 500 ? '服务器错误' : '请求失败';
      detail = 'HTTP $statusCode $requestPath';
      Log.e('ApiClient', 'HTTP错误 $codeStr | $requestPath', err);
    } else {
      codeStr = err.type == DioExceptionType.connectionTimeout
          ? 'TIMEOUT'
          : err.type == DioExceptionType.receiveTimeout
              ? 'TIMEOUT'
              : 'NETWORK';
      message = err.type == DioExceptionType.connectionTimeout
          ? '连接超时'
          : err.type == DioExceptionType.receiveTimeout
              ? '响应超时'
              : '网络连接失败';
      detail = '${err.type.name} — $requestPath';
      Log.e('ApiClient', '网络错误 $codeStr — $message | $requestPath', err);
    }

    showErrorDialog(
      title: '错误',
      errorCode: codeStr,
      message: message,
      detail: detail,
    );
    handler.next(err);
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
    if (options.baseUrl.isNotEmpty && options.extra['_baseUrlSet'] != true) {
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
      baseUrl: ApiConfig.chinaUrl,
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
    // 7. 错误弹窗（最后执行，捕获所有未被其他拦截器吞掉的异常）
    _dio.interceptors.add(_ErrorDialogInterceptor());
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

  Future<Response> get(String path,
      {Map<String, dynamic>? params, Options? options}) async {
    try {
      final response =
          await _dio.get(path, queryParameters: params, options: options);
      _checkNeedLogin(response.data,
          requestPath: _buildRequestUrl(path, params));
      return response;
    } on DioException catch (e) {
      if (e.response?.statusCode == 200) {
        final data = e.response?.data;
        if (data is Map)
          _checkNeedLogin(data, requestPath: _buildRequestUrl(path, params));
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
    bool withAuth = true,
  }) async {
    final extra = <String, dynamic>{'cache_ttl': ttl};
    if (!withAuth) extra['noAuth'] = true;
    try {
      return await _dio.get(
        path,
        queryParameters: params,
        options: Options(extra: extra),
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

  /// 构造不含 host 的请求 URL（/path?key=val），隐藏 IP
  static String _buildRequestUrl(String path, Map<String, dynamic>? params) {
    if (params == null || params.isEmpty) return path;
    final buf = StringBuffer('$path?');
    bool first = true;
    params.forEach((k, v) {
      if (!first) buf.write('&');
      first = false;
      buf.write('$k=$v');
    });
    return buf.toString();
  }

  void _checkNeedLogin(dynamic data, {String? requestPath}) {
    if (data is Map) {
      final status = data['status'] ?? data['code'];
      if (status == 20010 || status == '20010') {
        Log.e('ApiClient', '登录失效 API 20010 | ${requestPath ?? "?"}');
        // 立即清除过期 token，后续请求不再携带，公开接口可正常访问
        clearAuth();
        showErrorDialog(
          title: '登录失效',
          errorCode: 'API 20010',
          message: '登录已过期，请重新登录',
          detail: requestPath != null ? '请求路径: $requestPath' : null,
          showLogin: true,
        );
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

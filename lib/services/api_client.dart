import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import '../utils/constants.dart';

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;
  late final CookieJar _cookieJar;
  static String? _authToken;
  static String? _authUserId;
  static String? _dfid;

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

  ApiClient._() {
    _cookieJar = CookieJar();

    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {
        'User-Agent': AppConstants.userAgent,
      },
    ));

    _dio.interceptors.add(CookieManager(_cookieJar));
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (o) {},
    ));
  }

  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  Dio get dio => _dio;

  Future<Response> get(String path, {Map<String, dynamic>? params}) {
    return _dio.get(path, queryParameters: params);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<String> getCookieString() async {
    final uri = Uri.parse(AppConstants.baseUrl);
    final cookies = await _cookieJar.loadForRequest(uri);
    final parts = cookies.map((c) => '${c.name}=${c.value}').toList();
    if (_authToken != null) parts.add('token=$_authToken');
    if (_authUserId != null) parts.add('userid=$_authUserId');
    if (_dfid != null) parts.add('dfid=$_dfid');
    return parts.join(';');
  }
}

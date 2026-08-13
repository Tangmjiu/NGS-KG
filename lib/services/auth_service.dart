import 'api_client.dart';
import '../models/user.dart';

class AuthService {
  final ApiClient _client = ApiClient.instance;

  Future<User?> loginWithPhone(String mobile, String code) async {
    final res = await _client
        .get('/login/cellphone', params: {'mobile': mobile, 'code': code});
    return User.fromJson(res.data['data']);
  }

  Future<User?> loginWithPassword(String username, String password,
      {String? captcha}) async {
    final params = <String, dynamic>{
      'username': username,
      'password': password
    };
    if (captcha != null && captcha.isNotEmpty) {
      params['captcha'] = captcha;
    }
    final res = await _client.get('/login', params: params);
    final data = res.data;
    if (data['error_code'] != 0) {
      final msg = data['data']?.toString() ?? '登录失败';
      throw Exception(msg);
    }
    return User.fromJson(data['data']);
  }

  Future<Map<String, dynamic>> getQrKey() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final res = await _client
        .get('/login/qr/key', params: {'timestamp': ts.toString()});
    final rawData = res.data is Map ? (res.data as Map)['data'] : null;
    if (rawData is! Map) {
      throw const FormatException('二维码凭据响应格式无效');
    }
    return normalizeQrKeyData(Map<String, dynamic>.from(rawData));
  }

  Future<Map<String, dynamic>> getQrCreate(String key,
      {bool qrimg = false}) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final params = <String, dynamic>{'key': key, 'timestamp': ts.toString()};
    if (qrimg) params['qrimg'] = 1;
    final res = await _client.get('/login/qr/create', params: params);
    final rawData = res.data is Map ? (res.data as Map)['data'] : null;
    if (rawData is! Map) {
      throw const FormatException('二维码图片响应格式无效');
    }
    return normalizeQrImageData(Map<String, dynamic>.from(rawData));
  }

  /// 将不同 KuGouMusicApi 版本的凭据字段统一为 key，图片统一为 qrimg。
  ///
  /// 当前 API 的 /login/qr/key 返回 qrcode 和 qrcode_img；旧版客户端
  /// 约定则使用 key，图片通常由 /login/qr/create 返回。
  static Map<String, dynamic> normalizeQrKeyData(Map<String, dynamic> data) {
    final key = _firstNonEmptyString([data['key'], data['qrcode']]);
    if (key == null) {
      throw const FormatException('二维码接口未返回有效凭据');
    }

    final normalized = Map<String, dynamic>.from(data)..['key'] = key;
    final image = _firstNonEmptyString(
        [data['qrimg'], data['qrcode_img'], data['base64']]);
    if (image != null) normalized['qrimg'] = image;
    return normalized;
  }

  /// 将二维码图片字段统一为 qrimg。
  static Map<String, dynamic> normalizeQrImageData(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);
    final image = _firstNonEmptyString(
        [data['qrimg'], data['base64'], data['qrcode_img']]);
    if (image != null) normalized['qrimg'] = image;
    return normalized;
  }

  static String? _firstNonEmptyString(Iterable<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  Future<Map<String, dynamic>> checkQrStatus(String key) async {
    // 加上时间戳防止 API 缓存导致状态不更新
    final ts = DateTime.now().millisecondsSinceEpoch;
    final res = await _client.get('/login/qr/check',
        params: {'key': key, 'timestamp': ts.toString()});
    return res.data as Map<String, dynamic>;
  }

  /// Parses checkQrStatus response, extracts User if login succeeded.
  /// KuGou API 在扫码前返回 `"data": <int>`（纯状态码），
  /// 扫码成功后返回 `"data": { "status": 4, "token": "...", "userid": 123 }`。
  /// Returns (statusCode, user).
  static (int, User?) parseQrResponse(Map<String, dynamic> res) {
    final rawData = res['data'];

    // 情况 A：data 是纯数字（未扫码 / 等待确认 / 过期）
    if (rawData is num) return (rawData.toInt(), null);
    if (rawData is String) {
      return (int.tryParse(rawData) ?? 0, null);
    }

    // 情况 B：data 是 Map
    if (rawData is Map) {
      final status = rawData['status'] is num
          ? (rawData['status'] as num).toInt()
          : int.tryParse(rawData['status']?.toString() ?? '') ?? 0;
      if (status == 4) {
        final token =
            (rawData['token'] as String?) ?? rawData['token']?.toString() ?? '';
        final userId = (rawData['userid'] as int?) ??
            int.tryParse(rawData['userid']?.toString() ?? '');
        if (token.isNotEmpty && userId != null) {
          return (
            status,
            User(
              userId: userId,
              token: token,
              nickname: rawData['nickname'] as String?,
              avatarUrl: rawData['avatar'] as String?,
              vipType: rawData['vip_type'] as int?,
              isVip: rawData['is_vip'] as int?,
            )
          );
        }
      }
      // status 不是 4（如 1=等待扫码, 2=已扫码待确认）→ 直接返回 status
      return (status, null);
    }

    // 情况 C：未知格式
    return (0, null);
  }

  Future<void> sendCaptcha(String mobile) async {
    await _client.get('/captcha/sent', params: {'mobile': mobile});
  }

  Future<Map<String, dynamic>> getUserDetail() async {
    final res = await _client.get('/user/detail');
    return res.data['data'] as Map<String, dynamic>;
  }
}

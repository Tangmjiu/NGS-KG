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
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getQrCreate(String key,
      {bool qrimg = false}) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final params = <String, dynamic>{'key': key, 'timestamp': ts.toString()};
    if (qrimg) params['qrimg'] = 1;
    final res = await _client.get('/login/qr/create', params: params);
    return res.data['data'] as Map<String, dynamic>;
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
    if (rawData is int) return (rawData, null);

    // 情况 B：data 是 Map
    if (rawData is Map) {
      final status = (rawData['status'] as int?) ?? 0;
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

import 'api_client.dart';
import '../models/user.dart';

class AuthService {
  final ApiClient _client = ApiClient.instance;

  Future<User?> loginWithPhone(String mobile, String code) async {
    final res = await _client.get('/login/cellphone',
        params: {'mobile': mobile, 'code': code});
    return User.fromJson(res.data['data']);
  }

  Future<User?> loginWithPassword(String username, String password, {String? captcha}) async {
    final params = <String, dynamic>{'username': username, 'password': password};
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
    final res = await _client.get('/login/qr/key');
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<String> getQrCreate(String key) async {
    final res = await _client.get('/login/qr/create', params: {'key': key});
    return res.data['data']['qrUrl'] as String;
  }

  Future<Map<String, dynamic>> checkQrStatus(String key) async {
    final res = await _client.get('/login/qr/check', params: {'key': key});
    return res.data as Map<String, dynamic>;
  }

  Future<void> sendCaptcha(String mobile) async {
    await _client.get('/captcha/sent', params: {'mobile': mobile});
  }

  Future<Map<String, dynamic>> getUserDetail() async {
    final res = await _client.get('/user/detail');
    return res.data['data'] as Map<String, dynamic>;
  }
}

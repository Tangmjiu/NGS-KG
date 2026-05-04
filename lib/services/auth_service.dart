import 'api_client.dart';
import '../models/user.dart';

class AuthService {
  final ApiClient _client = ApiClient.instance;

  Future<User?> loginWithPhone(String phone, String code) async {
    final res = await _client.get('/login/cellphone',
        params: {'phone': phone, 'code': code});
    return User.fromJson(res.data['data']);
  }

  Future<User?> loginWithPassword(String username, String password) async {
    final res = await _client
        .get('/login', params: {'username': username, 'password': password});
    return User.fromJson(res.data['data']);
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

  Future<void> sendCaptcha(String phone) async {
    await _client.get('/captcha/sent', params: {'phone': phone});
  }

  Future<Map<String, dynamic>> getUserDetail() async {
    final res = await _client.get('/user/detail');
    return res.data['data'] as Map<String, dynamic>;
  }
}

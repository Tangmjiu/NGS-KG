import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;

  Future<bool> loginWithPassword(String username, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _authService.loginWithPassword(username, password);
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithPhone(String phone, String code) async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _authService.loginWithPhone(phone, code);
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> sendCaptcha(String phone) async {
    await _authService.sendCaptcha(phone);
  }

  Future<Map<String, dynamic>> getQrKey() async {
    return _authService.getQrKey();
  }

  Future<String> getQrCreate(String key) async {
    return _authService.getQrCreate(key);
  }

  Future<int> checkQrStatus(String key) async {
    return _authService.checkQrStatus(key);
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}

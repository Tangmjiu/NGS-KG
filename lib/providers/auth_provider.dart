import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _loadSavedUser();
  }

  Future<void> _loadSavedUser() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/user.json');
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        _user = User.fromJson(data as Map<String, dynamic>);
        ApiClient.setAuth(_user!.token, _user!.userId?.toString());
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveUser() async {
    if (_user == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/user.json');
      await file.writeAsString(jsonEncode(_user!.toJson()));
    } catch (_) {}
  }

  Future<void> _clearSavedUser() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/user.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<bool> loginWithPassword(String username, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _authService.loginWithPassword(username, password);
      _isLoading = false;
      notifyListeners();
      if (_user != null) {
        await _saveUser();
        ApiClient.setAuth(_user!.token, _user!.userId?.toString());
      }
      return _user != null;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithPhone(String mobile, String code) async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _authService.loginWithPhone(mobile, code);
      _isLoading = false;
      notifyListeners();
      if (_user != null) {
        await _saveUser();
        ApiClient.setAuth(_user!.token, _user!.userId?.toString());
      }
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
    final res = await _authService.checkQrStatus(key);
    final status = res['data'] is Map ? (res['data'] as Map)['status'] : null;
    if (status == 200 && res['data'] is Map) {
      final userData = (res['data'] as Map)['user'] as Map<String, dynamic>?;
      if (userData != null) {
        _user = User.fromJson(userData);
        ApiClient.setAuth(_user!.token, _user!.userId?.toString());
        _saveUser();
        notifyListeners();
      }
    }
    return (status as int?) ?? 0;
  }

  void logout() {
    _user = null;
    ApiClient.clearAuth();
    _clearSavedUser();
    notifyListeners();
  }
}

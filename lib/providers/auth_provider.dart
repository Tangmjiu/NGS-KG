import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../services/device_service.dart';
import 'liked_songs_provider.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  LikedSongsProvider? _likedSongs;
  final Completer<void> _readyCompleter = Completer<void>();

  User? _user;
  bool _isLoading = false;
  bool _isLoggingIn = false;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;

  /// 等待 _loadSavedUser() 完成后再执行依赖认证的初始化逻辑
  Future<void> get ready => _readyCompleter.future;

  AuthProvider(this._authService, {LikedSongsProvider? likedSongs})
      : _likedSongs = likedSongs {
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
    } catch (e, s) {
      Log.e('auth_provider', 'error', e, s);
    }
    _readyCompleter.complete();
  }

  Future<void> _saveUser() async {
    if (_user == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/user.json');
      await file.writeAsString(jsonEncode(_user!.toJson()));
    } catch (e, s) {
      Log.e('auth_provider', 'error', e, s);
    }
  }

  Future<void> _clearSavedUser() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/user.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e, s) {
      Log.e('auth_provider', 'error', e, s);
    }
  }

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<bool> loginWithPassword(String username, String password,
      {String? captcha}) async {
    if (_isLoggingIn) return false;
    _isLoggingIn = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _user = await _authService.loginWithPassword(username, password,
          captcha: captcha);
      _isLoading = false;
      _isLoggingIn = false;
      notifyListeners();
      if (_user != null) {
        await _saveUser();
        ApiClient.setAuth(_user!.token, _user!.userId?.toString());
      }
      return _user != null;
    } catch (e) {
      _isLoading = false;
      _isLoggingIn = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithPhone(String mobile, String code) async {
    if (_isLoggingIn) return false;
    _isLoggingIn = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _user = await _authService.loginWithPhone(mobile, code);
      _isLoading = false;
      _isLoggingIn = false;
      notifyListeners();
      if (_user != null) {
        await _saveUser();
        ApiClient.setAuth(_user!.token, _user!.userId?.toString());
      }
      return _user != null;
    } catch (e) {
      _isLoading = false;
      _isLoggingIn = false;
      _errorMessage = e.toString();
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

  Future<Map<String, dynamic>> getQrCreate(String key,
      {bool qrimg = false}) async {
    return _authService.getQrCreate(key, qrimg: qrimg);
  }

  Future<int> checkQrStatus(String key) async {
    final res = await _authService.checkQrStatus(key);
    final (status, user) = AuthService.parseQrResponse(res);
    if (user != null) {
      _user = user;
      ApiClient.setAuth(_user!.token, _user!.userId?.toString());
      _saveUser();
      notifyListeners();
    }
    return status;
  }

  void logout() {
    _user = null;
    ApiClient.clearAuth();
    DeviceService.instance.clear();
    _likedSongs?.clear();
    _clearSavedUser();
    notifyListeners();
  }
}

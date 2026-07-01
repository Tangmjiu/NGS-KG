import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// 音频设置：WiFi / 蜂窝 / 下载 三套独立音质
///
/// 持久化到 SharedPreferences，非登录场景也能生效。
class AudioSettingsProvider extends ChangeNotifier {
  static const _keyWifi = 'audio_quality_wifi';
  static const _keyCellular = 'audio_quality_cellular';
  static const _keyDownload = 'audio_quality_download';
  static const _keySmartMode = 'audio_quality_smart';
  static const _keyUploadHistory = 'audio_upload_history';
  static const _keyCrossfade = 'audio_crossfade_enabled';
  static const _keyCrossfadeDuration = 'audio_crossfade_ms';

  /// 默认值：WiFi 无损，蜂窝标准，下载无损，智能关
  static const defaultWifi = 'high';
  static const defaultCellular = '128';
  static const defaultDownload = 'high';

  String _wifiQuality = defaultWifi;
  String _cellularQuality = defaultCellular;
  String _downloadQuality = defaultDownload;
  bool _smartMode = false;
  bool _uploadHistory = true;
  bool _crossfadeEnabled = false;
  int _crossfadeMs = 2000;

  // ─── Getters ───

  String get wifiQuality => _wifiQuality;
  String get cellularQuality => _cellularQuality;
  String get downloadQuality => _downloadQuality;
  bool get smartMode => _smartMode;
  bool get uploadHistory => _uploadHistory;
  bool get crossfadeEnabled => _crossfadeEnabled;
  int get crossfadeMs => _crossfadeMs;

  // ─── 初始化 ───

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _wifiQuality = prefs.getString(_keyWifi) ?? defaultWifi;
      _cellularQuality = prefs.getString(_keyCellular) ?? defaultCellular;
      _downloadQuality = prefs.getString(_keyDownload) ?? defaultDownload;
      _smartMode = prefs.getBool(_keySmartMode) ?? false;
      _uploadHistory = prefs.getBool(_keyUploadHistory) ?? true;
      _crossfadeEnabled = prefs.getBool(_keyCrossfade) ?? false;
      _crossfadeMs = prefs.getInt(_keyCrossfadeDuration) ?? 2000;
      notifyListeners();
    } catch (e, s) {
      Log.e('AudioSettings', 'init error', e, s);
    }
  }

  // ─── Setters（自动持久化） ───

  Future<void> setWifiQuality(String key) async {
    _wifiQuality = key;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWifi, key);
  }

  Future<void> setCellularQuality(String key) async {
    _cellularQuality = key;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCellular, key);
  }

  Future<void> setDownloadQuality(String key) async {
    _downloadQuality = key;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDownload, key);
  }

  Future<void> setUploadHistory(bool value) async {
    _uploadHistory = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUploadHistory, value);
  }

  Future<void> setSmartMode(bool value) async {
    _smartMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySmartMode, value);
  }

  Future<void> setCrossfadeEnabled(bool value) async {
    _crossfadeEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCrossfade, value);
  }

  Future<void> setCrossfadeMs(int ms) async {
    _crossfadeMs = ms;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCrossfadeDuration, ms);
  }

  /// 获取当前网络应使用的音质上限
  /// [isWifi]：是否 WiFi 网络
  String getEffectiveQuality(bool isWifi) {
    if (_smartMode) {
      // 智能模式：WiFi 用用户设定的 WiFi 音质上限，蜂窝按用户设定
      return isWifi ? _wifiQuality : _cellularQuality;
    }
    return isWifi ? _wifiQuality : _cellularQuality;
  }
}

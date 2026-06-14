import 'dart:convert';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_info.dart';
import 'kugou_signer.dart';
import 'api_client.dart';

/// 设备注册与管理服务
///
/// 负责：
/// 1. 首次启动时调用 /register/dev 注册设备
/// 2. 持久化完整设备指纹（dfid/mid/guid/serverDev/mac）
/// 3. 从本地恢复设备信息
/// 4. 提供设备指纹供 ApiClient 拦截器使用
class DeviceService {
  static DeviceService? _instance;
  static const String _prefsKey = 'device_info';

  DeviceInfo? _cached;

  DeviceService._();

  static DeviceService get instance {
    _instance ??= DeviceService._();
    return _instance!;
  }

  /// 获取当前设备信息（优先缓存，其次 SharedPreferences）
  Future<DeviceInfo?> getDeviceInfo() async {
    if (_cached != null && _cached!.isValid) return _cached;
    _cached = await _loadFromPrefs();
    return _cached;
  }

  /// 注册设备——调用 API 获取 dfid，本地生成其余字段
  ///
  /// 流程：
  /// 1. 本地生成 guid/mid/serverDev/mac
  /// 2. 调用 /register/dev 获取 dfid
  /// 3. 组装完整 DeviceInfo 并持久化
  Future<DeviceInfo> registerDevice() async {
    // 本地生成设备标识
    final guid = KugouSigner.generateGuid();
    final mid = KugouSigner.calculateMid(guid);
    final serverDev = KugouSigner.randomString(10).toUpperCase();
    const mac = '02:00:00:00:00:00';

    // 从 API 注册获取 dfid
    String dfid = '';
    try {
      final client = ApiClient.instance;
      final res = await client.dio.get(
        '/register/dev',
        options: _noAuthOptions(),
      );
      final data = res.data;
      if (data is Map) {
        final inner = data['data'] as Map<String, dynamic>? ?? data;
        dfid = (inner['dfid'] as String?) ?? '';
      }
    } catch (_) {
      // 降级：使用本地生成的 dfid 回退值
      dfid = 'dfid-${KugouSigner.randomString(8)}';
    }

    final info = DeviceInfo(
      dfid: dfid,
      mid: mid,
      guid: guid,
      serverDev: serverDev,
      mac: mac,
    );

    _cached = info;
    await _saveToPrefs(info);

    // 同时更新 ApiClient 中的静态 dfid（兼容旧代码）
    ApiClient.setDfid(dfid);

    return info;
  }

  /// 仅刷新 dfid（当设备被拒绝时重新注册）
  Future<String> refreshDfid() async {
    final info = await registerDevice();
    return info.dfid;
  }

  /// 清除设备信息
  Future<void> clear() async {
    _cached = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  static const _deviceChannel = MethodChannel('com.mjiutang.ngskg/device');

  /// 获取当前设备的主 ABI（如 arm64-v8a / armeabi-v7a / x86_64）。
  /// Android 上通过原生 Build.SUPPORTED_ABIS 获取，其他平台返回 null。
  Future<String?> getAbi() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _deviceChannel.invokeMethod<String>('getAbi');
    } catch (_) {
      return null;
    }
  }

  /// 构建 Authorization 头（便捷方法）
  Future<Map<String, String>> buildAuthHeaders({
    String? token,
    String? userId,
  }) async {
    final device = await getDeviceInfo();
    final authHeader = device?.buildAuthHeader(token: token, userId: userId);
    if (authHeader != null && authHeader.isNotEmpty) {
      return {'Authorization': authHeader};
    }
    return {};
  }

  // ─── 私有 ───

  Options _noAuthOptions() {
    return Options(extra: {'noAuth': true});
  }

  Future<void> _saveToPrefs(DeviceInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(info.toJson()));
  }

  Future<DeviceInfo?> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return DeviceInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

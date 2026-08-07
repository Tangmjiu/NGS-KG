// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../services/device_service.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';
import 'network/dev_network_monitor.dart';

/// 开发者导出服务（debug/profile 专用）
///
/// - [exportLogs]：规范格式日志导出（时间戳/级别/标签），文件名 `ngs_kg_log_日期_时间.txt`
/// - [exportAppData]：应用数据（API 配置/设备信息/设置/缓存统计/网络记录）导出为 JSON
/// - 导出后统一调用系统分享面板（share_plus）
// 优化功能：日志导出（重新实现）
// 新增功能：导出应用数据
class ExportService {
  ExportService._();

  static final ExportService instance = ExportService._();

  /// URL query 中的敏感参数名（与 DevNetworkMonitor.sensitiveQueryKeys 共享，
  /// 值与 host/path 保留以便排查）
  static final Pattern _sensitiveQueryParam = RegExp(
    '([?&](?:${DevNetworkMonitor.sensitiveQueryKeys.join('|')})=)[^&"\\s]+',
    caseSensitive: false,
  );

  /// 错误响应体（raw: {...} 段）中的敏感键值（JSON 键值对形式）
  static final Pattern _sensitiveJsonValue = RegExp(
    '("(?:cookie|token|userid|dfid|guid|mid|password|secret|sign|sig|api_key|auth|session)":\\s*")[^"]*(")',
    caseSensitive: false,
  );

  /// 导出日志文件（规范格式：时间戳 级别 [标签] 消息；URL 与响应体敏感参数已打码）
  static Future<File> exportLogs() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ngs_kg_log_${_timestamp()}.txt');
    final entries = Log.entries;
    final sb = StringBuffer()
      ..writeln('NGS-KG+ 日志导出')
      ..writeln('导出时间: ${DateTime.now().toIso8601String()}')
      ..writeln('共 ${entries.length} 条（URL 与响应体中的敏感参数已脱敏）')
      ..writeln('────────────────────────────');
    for (final e in entries) {
      sb.writeln(_sanitizeLogLine(e.formatted));
    }
    await file.writeAsString(sb.toString());
    return file;
  }

  /// 单行日志脱敏：URL query 与 raw 响应体中的敏感参数值 → ***
  static String _sanitizeLogLine(String line) {
    var result =
        line.replaceAllMapped(_sensitiveQueryParam, (m) => '${m.group(1)}***');
    result = result.replaceAllMapped(
        _sensitiveJsonValue, (m) => '${m.group(1)}***${m.group(2)}');
    return result;
  }

  /// 导出应用数据 JSON（敏感字段脱敏）
  static Future<File> exportAppData() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ngs_kg_data_${_timestamp()}.json');

    final prefs = await SharedPreferences.getInstance();
    final prefsMap = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      prefsMap[key] = _maskSensitive(key, prefs.get(key));
    }

    String baseUrl = '';
    String mode = '';
    try {
      baseUrl = await ApiConfig.instance.getBaseUrl();
      mode = await ApiConfig.instance.getMode();
    } catch (_) {}

    Map<String, dynamic>? device;
    try {
      final d = await DeviceService.instance.getDeviceInfo();
      if (d != null) {
        // 设备指纹（dfid/mid/guid/mac）参与认证头注入，属于敏感标识，整体打码
        device = {
          'dfid': '***',
          'mid': '***',
          'guid': '***',
          'serverDev': '***',
          'mac': '***',
          'isValid': d.isValid,
        };
      }
    } catch (_) {}

    final monitor = DevNetworkMonitor.instance;
    final data = <String, dynamic>{
      'exportedAt': DateTime.now().toIso8601String(),
      'app': {'name': AppConstants.appName},
      'api': {
        'mode': mode,
        'baseUrl': baseUrl,
        'connectTimeoutMs': AppConstants.connectTimeout.inMilliseconds,
        'receiveTimeoutMs': AppConstants.receiveTimeout.inMilliseconds,
        'lastRequestTime':
            monitor.lastRequestTime?.toIso8601String() ?? '（无请求）',
        'userId': ApiClient.userId == null ? '未登录' : '***',
      },
      'device': device,
      'prefs': prefsMap,
      'cache': await _cacheStats(),
      'network': {
        'offlineSimulated': monitor.offline,
        'recentRequests': monitor.entries
            .skip(monitor.entries.length > 20 ? monitor.entries.length - 20 : 0)
            .map((e) => e.toJson())
            .toList(),
      },
    };

    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return file;
  }

  /// 调用系统分享面板分享文件
  static Future<void> shareFile(File file, {String? title}) async {
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/plain')],
      subject: title,
      text: title,
    );
  }

  // ─── 私有 ───

  static Future<Map<String, dynamic>> _cacheStats() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbFile = File('${dir.path}/cache.db');
      final size = await dbFile.exists() ? await dbFile.length() : 0;
      return {
        'dbFile': dbFile.path,
        'dbSizeBytes': size,
        'maxEntries': 2000,
      };
    } catch (_) {
      return {'error': '无法读取缓存统计'};
    }
  }

  /// 可安全原样导出的设置键前缀（主题/音质设置不含敏感信息）
  static const List<String> _safePrefsPrefixes = ['theme_', 'audio_'];

  /// prefs 值脱敏：白名单前缀原样导出，其余键一律打码
  ///
  /// 设备指纹（device_info）、认证、用户信息及任何未知键均不导出明文，
  /// 避免依赖键名字面匹配导致漏网。
  static dynamic _maskSensitive(String key, dynamic value) {
    final lower = key.toLowerCase();
    if (_safePrefsPrefixes.any(lower.startsWith)) return value;
    return '***';
  }

  static String _timestamp() {
    final n = DateTime.now();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${p(n.month)}${p(n.day)}_${p(n.hour)}${p(n.minute)}${p(n.second)}';
  }
}

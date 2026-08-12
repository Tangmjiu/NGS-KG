// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/foundation.dart';

/// 单条网络请求记录
// 新增功能：网络请求监控
class DevNetworkEntry {
  final DateTime time;
  final String method;
  final String url;
  final int? statusCode;
  final int durationMs;
  final String? error;

  /// 是否为离线模拟拦截的请求
  final bool blocked;

  const DevNetworkEntry({
    required this.time,
    required this.method,
    required this.url,
    this.statusCode,
    this.durationMs = 0,
    this.error,
    this.blocked = false,
  });

  Map<String, dynamic> toJson() => {
        't': time.toIso8601String(),
        'method': method,
        'url': url,
        if (statusCode != null) 'status': statusCode,
        'durationMs': durationMs,
        if (error != null) 'error': error,
        'blocked': blocked,
      };
}

/// 网络请求监控器（debug/profile 专用，单例）
///
/// - 环形缓冲保存最近 [maxEntries] 条请求记录
/// - 维护"上次请求时间"供开发者信息页展示
/// - 持有离线模拟状态，供 [DevNetworkInterceptor] 查询
// 新增功能：网络请求监控
class DevNetworkMonitor {
  DevNetworkMonitor._();

  static final DevNetworkMonitor instance = DevNetworkMonitor._();

  static const int maxEntries = 200;

  final List<DevNetworkEntry> _entries = [];
  bool _offline = false;
  DateTime? _lastRequestTime;

  /// 列表变更通知（revision 自增，UI 用 ValueListenableBuilder 监听）
  final ValueNotifier<int> revision = ValueNotifier(0);

  bool get offline => _offline;
  DateTime? get lastRequestTime => _lastRequestTime;

  List<DevNetworkEntry> get entries => List.unmodifiable(_entries);

  /// 开启/关闭离线模拟（开启后所有经拦截器的请求立即被拒绝）
  void setOffline(bool value) {
    if (_offline == value) return;
    _offline = value;
    _add(DevNetworkEntry(
      time: DateTime.now(),
      method: 'OFFLINE',
      url: value ? '离线模拟已开启，请求将被拦截' : '离线模拟已恢复，请求放行',
      blocked: true,
    ));
  }

  /// 请求发出前调用：更新上次请求时间
  void recordRequest(String method, String url) {
    _lastRequestTime = DateTime.now();
  }

  /// 记录成功响应
  void recordResponse(
      String method, String url, int statusCode, int durationMs) {
    _add(DevNetworkEntry(
      time: DateTime.now(),
      method: method,
      url: url,
      statusCode: statusCode,
      durationMs: durationMs,
    ));
  }

  /// 记录失败请求（[blocked] 表示被离线模拟拦截）
  void recordError(String method, String url, String error, int durationMs,
      {bool blocked = false}) {
    _add(DevNetworkEntry(
      time: DateTime.now(),
      method: method,
      url: url,
      durationMs: durationMs,
      error: error,
      blocked: blocked,
    ));
  }

  void _add(DevNetworkEntry entry) {
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
    revision.value++;
  }

  void clear() {
    _entries.clear();
    revision.value++;
  }

  /// URL 脱敏敏感参数名（共享给 export_service 构建脱敏正则）
  ///
  /// 含主 API（cookie/token/dfid 等）与 Subsonic/Navidrome 认证键（u/t/s），
  /// 以及常见复合键（access_token/refresh_token/x-api-key），防未来接线后漂移泄露。
  static const Set<String> sensitiveQueryKeys = {
    'cookie',
    'token',
    'userid',
    'dfid',
    'guid',
    'mid',
    'password',
    'secret',
    'api_key',
    'auth',
    'session',
    'sign',
    'sig',
    'access_token',
    'refresh_token',
    'x-api-key',
    'uuid',
    'u',
    't',
    's',
  };

  /// URL 脱敏：隐藏 query 中的敏感参数值（cookie/token/userid 等）
  static String sanitizeUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.query.isEmpty) return url;
    final params = uri.queryParametersAll.map((k, v) {
      final key = k.toLowerCase();
      return MapEntry(
        k,
        sensitiveQueryKeys.contains(key) ? v.map((_) => '***').toList() : v,
      );
    });
    return uri.replace(queryParameters: params).toString();
  }
}

// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:dio/dio.dart';

import 'dev_network_monitor.dart';

/// 开发者网络监控拦截器（debug/profile 专用）
///
/// 挂在 ApiClient 拦截器链**最前端**：
/// - 离线模拟开启时，所有请求立即被拒绝（`unknown` 类型 → 不触发重试；
///   标记 `silent` → 不弹错误框），恢复后自动放行。
/// - 其余请求记录开始时间，在响应/错误阶段写入 [DevNetworkMonitor]。
// 新增功能：网络请求监控 + 模拟网络断开
class DevNetworkInterceptor extends Interceptor {
  static const String _startKey = '_devStartTime';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final monitor = DevNetworkMonitor.instance;
    if (monitor.offline) {
      // 离线模拟：立即拒绝（silent 避免 ErrorDialog 弹窗，unknown 避免重试）
      options.extra['silent'] = true;
      final err = DioException(
        requestOptions: options,
        type: DioExceptionType.unknown,
        message: '离线模拟（开发者工具）',
      );
      monitor.recordError(
        options.method,
        DevNetworkMonitor.sanitizeUrl(options.uri.toString()),
        '离线模拟拦截',
        0,
        blocked: true,
      );
      handler.reject(err);
      return;
    }
    options.extra[_startKey] = DateTime.now();
    monitor.recordRequest(
      options.method,
      DevNetworkMonitor.sanitizeUrl(options.uri.toString()),
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final start = response.requestOptions.extra[_startKey] as DateTime?;
    final durationMs =
        start == null ? 0 : DateTime.now().difference(start).inMilliseconds;
    DevNetworkMonitor.instance.recordResponse(
      response.requestOptions.method,
      DevNetworkMonitor.sanitizeUrl(response.requestOptions.uri.toString()),
      response.statusCode ?? 0,
      durationMs,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final start = err.requestOptions.extra[_startKey] as DateTime?;
    // 未被 onRequest 记录（离线模拟拦截在 onRequest 已记录）→ 不重复记录
    if (start == null) {
      handler.next(err);
      return;
    }
    final durationMs = DateTime.now().difference(start).inMilliseconds;
    DevNetworkMonitor.instance.recordError(
      err.requestOptions.method,
      DevNetworkMonitor.sanitizeUrl(err.requestOptions.uri.toString()),
      '${err.type.name}: ${err.message}',
      durationMs,
    );
    handler.next(err);
  }
}

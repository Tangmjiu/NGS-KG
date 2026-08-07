// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../../services/api_config.dart';
import '../../../services/remote_config_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/logger.dart';
import '../network/dev_network_monitor.dart';
import 'section_card.dart';

/// 开发者信息 — API 信息分组
///
/// 优化项：环境标识、API 版本（客户端）、超时时间、上次请求时间。
/// 保留原"清除 Cookie"功能（重命名"清除认证信息"）。
// 优化功能：API 信息展示
class ApiInfoSection extends StatefulWidget {
  const ApiInfoSection({super.key});

  @override
  State<ApiInfoSection> createState() => _ApiInfoSectionState();
}

class _ApiInfoSectionState extends State<ApiInfoSection> {
  String _baseUrl = '加载中…';
  String _envLabel = '—';
  String _userId = '未登录';
  String _lastRequest = '—';
  DateTime? _lastRequestTime;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final baseUrl = await ApiConfig.instance.getBaseUrl();
      final mode = await ApiConfig.instance.getMode();
      final remote = RemoteConfigService.instance.getValidCachedBaseUrl();
      final envLabel = remote != null && remote.isNotEmpty
          ? '远程配置'
          : mode == ApiConfig.modeCustom
              ? '自定义服务器'
              : '内置域名（mjiutang）';
      if (!mounted) return;
      setState(() {
        _baseUrl = baseUrl;
        _envLabel = envLabel;
        _userId = ApiClient.userId ?? '未登录';
        _lastRequestTime = DevNetworkMonitor.instance.lastRequestTime;
        _lastRequest = _lastRequestTime == null
            ? '尚无请求'
            : '${_fmtTime(_lastRequestTime!)} · ${_lastRequestTime!.toLocal().toIso8601String()}';
      });
    } catch (e) {
      Log.w('DEVTOOLS', 'API 信息加载失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearAuth(BuildContext context) async {
    ApiClient.clearAuth();
    setState(() => _userId = '未登录');
    Log.i('DEVTOOLS', '认证信息已清除');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('认证信息已清除'),
      duration: Duration(seconds: 2),
    ));
  }

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return DeveloperSectionCard(
      icon: Icons.dns_outlined,
      title: 'API 信息',
      subtitle: '环境、超时、请求状态',
      initiallyExpanded: false,
      children: [
        DevInfoRow(
          label: '环境标识',
          value: _envLabel,
          icon: Icons.flag_outlined,
        ),
        DevInfoRow(
          label: 'API 地址',
          value: _baseUrl,
          icon: Icons.link,
        ),
        DevInfoRow(
          label: '超时时间',
          value:
              '连接 ${AppConstants.connectTimeout.inSeconds}s / 响应 ${AppConstants.receiveTimeout.inSeconds}s',
          icon: Icons.timer_outlined,
        ),
        DevInfoRow(
          label: '上次请求',
          value: _lastRequest,
          icon: Icons.history,
        ),
        DevInfoRow(
          label: '登录状态',
          value: _userId == '未登录' ? '未登录' : 'userid: $_userId',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('刷新'),
            ),
            TextButton.icon(
              onPressed: () => _clearAuth(context),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('清除认证信息'),
            ),
          ],
        ),
      ],
    );
  }
}

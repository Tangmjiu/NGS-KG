// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';
import 'section_card.dart';

/// 调试与日志分组
///
/// - 日志查看器（复用现有 LogViewerScreen，支持级别/tag 过滤）
/// - 网络请求监控（请求/响应详情列表页）
/// - 路由日志（AppRouteObserver 实时记录导航栈变化，Tag: ROUTE）
// 新增功能：日志查看器入口 / 网络请求监控 / 路由日志
class DebugLogsSection extends StatelessWidget {
  const DebugLogsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return DeveloperSectionCard(
      icon: Icons.article_outlined,
      title: '调试与日志',
      subtitle: '应用日志、网络监控、路由记录',
      initiallyExpanded: false,
      children: [
        ListTile(
          leading: const Icon(Icons.subject_outlined),
          title: const Text('日志查看器'),
          subtitle: const Text('应用内实时查看日志，支持级别/Tag 过滤'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, AppRoutes.logViewer),
        ),
        ListTile(
          leading: const Icon(Icons.network_check),
          title: const Text('网络请求监控'),
          subtitle: const Text('拦截并展示 HTTP 请求/响应详情'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, AppRoutes.networkMonitor),
        ),
        const ListTile(
          leading: Icon(Icons.route_outlined),
          title: Text('路由日志'),
          subtitle: Text('导航栈变化已实时记录（日志 Tag: ROUTE）'),
          trailing: Icon(Icons.check_circle_outline, color: Colors.green),
        ),
      ],
    );
  }
}

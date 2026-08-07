// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../utils/theme.dart';
import 'dev_network_monitor.dart';

/// 网络请求监控页（debug/profile 专用）
///
/// 展示 DevNetworkInterceptor 拦截到的请求/响应详情：
/// 方法、URL（敏感参数已脱敏）、状态码、耗时、错误信息。
// 新增功能：网络请求监控
class NetworkLogScreen extends StatelessWidget {
  const NetworkLogScreen({super.key});

  Color _statusColor(int? status) {
    if (status == null) return Colors.redAccent;
    if (status >= 200 && status < 300) return Colors.green;
    if (status >= 300 && status < 400) return Colors.orange;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('网络请求监控'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: '清空记录',
            onPressed: () => DevNetworkMonitor.instance.clear(),
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: DevNetworkMonitor.instance.revision,
        builder: (_, __, ___) {
          final entries = DevNetworkMonitor.instance.entries;
          if (entries.isEmpty) {
            return const Center(child: Text('暂无网络请求记录'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: entries.length,
            itemBuilder: (_, i) {
              final e = entries[i];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: AppShape.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: e.blocked
                                ? Colors.orange.withValues(alpha: 0.2)
                                : Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.15),
                            borderRadius: AppShape.xs,
                          ),
                          child: Text(
                            e.method,
                            style: textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: e.blocked
                                  ? Colors.orange
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.url,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (e.blocked)
                          Text('拦截',
                              style: textTheme.labelSmall
                                  ?.copyWith(color: Colors.orange))
                        else if (e.error != null)
                          Text('失败',
                              style: textTheme.labelSmall
                                  ?.copyWith(color: Colors.redAccent))
                        else
                          Text(
                            '${e.statusCode}',
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: _statusColor(e.statusCode),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${e.time.hour.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')}:${e.time.second.toString().padLeft(2, '0')}.${e.time.millisecond.toString().padLeft(3, '0')}',
                          style: textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline),
                        ),
                        const SizedBox(width: 12),
                        Text('耗时 ${e.durationMs}ms',
                            style: textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline)),
                        if (e.error != null) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              e.error!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall
                                  ?.copyWith(color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

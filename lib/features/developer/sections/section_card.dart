// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../utils/theme.dart';

/// MD3E 分组卡片 — 开发者页各功能组的统一容器
///
/// Card（elevation 0 + 色彩层级）+ ExpansionTile 折叠，复用项目
/// AppShape/AppMotion 令牌，遵循 MD3E 设计规范。
class DeveloperSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool initiallyExpanded;

  const DeveloperSectionCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.children,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ExpansionTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        initiallyExpanded: initiallyExpanded,
        shape: const RoundedRectangleBorder(
          borderRadius: AppShape.lg,
        ),
        collapsedShape: const RoundedRectangleBorder(
          borderRadius: AppShape.lg,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// MD3E 信息行 — 键值对展示（API/设备信息用）
class DevInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const DevInfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.outline),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.outline)),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// MD3E 实时指标卡（页面顶部实时指标区用）
class DevMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const DevMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color ?? cs.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// 发现页区块标题行 — "标题" + 可选 "查看更多"
class DiscoverSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;
  final EdgeInsetsGeometry padding;

  const DiscoverSectionHeader({
    super.key,
    required this.title,
    this.onViewAll,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 12),
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onViewAll != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onViewAll,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  '查看更多',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

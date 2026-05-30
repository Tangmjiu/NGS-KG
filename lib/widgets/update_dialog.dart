import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_checker.dart';

/// 发现新版本弹窗
Future<void> showUpdateDialog(BuildContext context, ReleaseInfo release) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.system_update, size: 22, color: Colors.green),
          const SizedBox(width: 8),
          const Expanded(child: Text('发现新版本')),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 版本信息
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    release.tagName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 更新日志
            if (release.body.isNotEmpty) ...[
              Text('更新日志',
                  style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 240),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    release.body,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          height: 1.5,
                        ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('稍后再说'),
        ),
        if (release.downloadUrl != null)
          FilledButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text('下载更新'),
            onPressed: () {
              final uri = Uri.tryParse(release.downloadUrl!);
              if (uri != null) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              Navigator.pop(ctx);
            },
          ),
      ],
    ),
  );
}

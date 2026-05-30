import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' as app;
import '../theme/theme_assets.dart';

/// 显示错误弹窗
///
/// [title]     : 弹窗标题，默认 '错误'
/// [message]   : 错误详情
/// [errorCode] : 可选的错误代码（HTTP 状态码 / API 错误码）
/// [detail]    : 可选的额外详细信息（JSON body、请求路径等）
/// [showLogin] : 为 true 时将"我知道了"替换为"登录"，点击跳转登录页
///
/// 无需 BuildContext，自动使用全局 navKey。
void showErrorDialog({
  String title = '错误',
  required String message,
  String? errorCode,
  String? detail,
  bool showLogin = false,
}) {
  final ctx = app.navKey.currentContext;
  if (ctx == null) return;

  // 组装复制文本
  final copyText = StringBuffer()
    ..writeln('=== 错误信息 ===')
    ..writeln('标题: $title');
  if (errorCode != null) copyText.writeln('错误代码: $errorCode');
  copyText.writeln('原因: $message');
  if (detail != null && detail.isNotEmpty) copyText.writeln('详情: $detail');
  copyText.writeln('---');
  copyText.writeln('NGS-KG+');

  showDialog(
    context: ctx,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error_outline, size: 22, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 错误提示图
            ThemeImage(
              assetPath: ThemeAssets.sthiswrong,
              width: 80,
              height: 80,
            ),
            const SizedBox(height: 12),
            // 错误代码
            if (errorCode != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  errorCode,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            // 错误原因
            SelectableText(message, style: Theme.of(context).textTheme.bodyMedium),
            // 详细信息
            if (detail != null && detail.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // 复制按钮
        TextButton.icon(
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('复制'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: copyText.toString()));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 2)),
            );
          },
        ),
        // 取消
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        // 登录 / 我知道了
        if (showLogin)
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/login');
            },
            child: const Text('登录'),
          )
        else
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('我知道了'),
          ),
      ],
    ),
  );
}

/// 从异常对象提取可读的错误消息
String errorMessage(dynamic error) {
  if (error == null) return '未知错误';
  if (error is String) return error;
  try {
    return error.toString();
  } catch (_) {
    return '未知错误';
  }
}

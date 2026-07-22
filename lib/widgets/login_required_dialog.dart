import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// 未登录提示弹窗
///
/// 返回 true 表示用户点击了"登录"按钮。
Future<bool> showLoginRequiredDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('请登录'),
      content: const Text('该功能需要登录后才能使用'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('知道了'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('登录'),
        ),
      ],
    ),
  );
  return result ?? false;
}

import 'package:flutter/material.dart';
import '../watch/screens/login_screen.dart';

/// Wear OS 风格未登录提示弹窗
///
/// 返回 true 表示用户点击了"登录"按钮。
Future<bool> showLoginRequiredDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _WatchLoginDialog(),
  );
  return result ?? false;
}

class _WatchLoginDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_circle_rounded, size: 40, color: cs.primary),
          const SizedBox(height: 12),
          Text(
            '请登录',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '该功能需要登录后才能使用',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      actions: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('知道了', style: TextStyle(fontSize: 14)),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              Navigator.pop(context, true);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WatchLoginScreen(),
                ),
              );
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('登录', style: TextStyle(fontSize: 14)),
          ),
        ),
      ],
    );
  }
}

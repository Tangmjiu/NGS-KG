import 'package:flutter/material.dart';
import '../main.dart' as app;

/// 显示错误弹窗
///
/// [title]     : 弹窗标题，默认 '错误'
/// [message]   : 错误详情
/// [showLogin] : 为 true 时将"我知道了"替换为"登录"，点击跳转登录页
///
/// 无需 BuildContext，自动使用全局 navKey。
void showErrorDialog({
  String title = '错误',
  required String message,
  bool showLogin = false,
}) {
  final ctx = app.navKey.currentContext;
  if (ctx == null) return;

  showDialog(
    context: ctx,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Text(message),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
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

// CI trigger - force build

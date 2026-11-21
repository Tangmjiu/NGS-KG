// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import '../watch/screens/login_screen.dart';

Future<bool>? _prompt;
bool _openingLogin = false;

/// 登录入口由提示页统一打开。返回值表示用户是否选择了登录。
Future<bool> showLoginRequiredDialog(BuildContext context) {
  if (_openingLogin) return Future.value(false);
  return _prompt ??= _ask(context).whenComplete(() => _prompt = null);
}

Future<bool> _ask(BuildContext context) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final source = ModalRoute.of(context);
  if (source != null && !source.isCurrent) return false;
  final result = await showDialog<bool>(
    context: context,
    useSafeArea: false,
    animationStyle: AnimationStyle.noAnimation,
    builder: (ctx) => WatchFlowPage(
      title: '请先登录',
      center: true,
      children: [
        const Text('这项功能需要酷狗账号。', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('登录'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('暂不登录'),
        ),
      ],
    ),
  );
  if (result == true &&
      navigator.mounted &&
      (source == null || source.isCurrent)) {
    openWatchLogin(navigator);
  }
  return result ?? false;
}

void openWatchLogin(NavigatorState navigator) {
  if (_openingLogin || !navigator.mounted) return;
  _openingLogin = true;
  navigator
      .push<void>(
        MaterialPageRoute<void>(builder: (_) => const WatchLoginScreen()),
      )
      .whenComplete(() => _openingLogin = false);
}

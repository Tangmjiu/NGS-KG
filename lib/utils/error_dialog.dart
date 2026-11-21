// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../watch/screens/login_screen.dart';
import 'login_required_dialog.dart';
import 'navigation.dart' as app;

final _visibleErrors = <(String, String, String?)>{};
final _sensitiveField = RegExp(
  r'''\b(?:authorization|bearer|(?:set-)?cookie|(?:access[_-]?|refresh[_-]?)?token|session(?:id)?|password|(?:api[_-]?)?key|secret|user[_-]?id|dfid|mid|guid|serverdev|mac|phone|mobile|signature|sign|captcha|otp|qrcode(?:_img)?|qrimg|base64)\b|\bcode["' ]*[:=]|\b1\d{10}\b|验证码\s*[:：=]?\s*\d+''',
  caseSensitive: false,
);

String _mask(String text) => text
    .split('\n')
    .map((line) {
      final query = line.indexOf('?');
      final visible = query < 0 ? line : line.substring(0, query);
      if (_sensitiveField.hasMatch(visible)) return '［敏感信息已隐藏］';
      return query < 0 ? visible : '$visible?…';
    })
    .join('\n');

void showErrorDialog({
  String title = '错误',
  required String message,
  String? errorCode,
  String? detail,
  bool showLogin = false,
}) {
  final context = app.navKey.currentContext;
  if (context == null) return;
  final login = showLogin || errorCode == 'API 20010' || errorCode == '20010';
  final heading = login ? '请重新登录' : _mask(title);
  final reason = _mask(message).trim();
  final code = errorCode == null ? null : _mask(errorCode);
  final key = login ? (heading, '', null) : (heading, reason, code);
  if (!_visibleErrors.add(key)) return;
  final report = [
    heading,
    if (code != null) '错误代码：$code',
    if (reason.isNotEmpty) reason,
    if (detail != null && detail.isNotEmpty) _mask(detail),
  ].join('\n');
  showDialog<bool>(
        context: context,
        useSafeArea: false,
        barrierDismissible: false,
        animationStyle: AnimationStyle.noAnimation,
        builder: (_) => _WatchErrorDialog(
          heading: heading,
          login: login,
          report: report,
          summary: login
              ? '账号登录已过期。'
              : (reason.isEmpty ? '操作未完成' : reason.split('\n').first),
        ),
      )
      .then((open) {
        final navigator = app.navKey.currentState;
        if (open == true && navigator != null) openWatchLogin(navigator);
      })
      .whenComplete(() {
        _visibleErrors.remove(key);
      });
}

class _WatchErrorDialog extends StatefulWidget {
  const _WatchErrorDialog({
    required this.heading,
    required this.summary,
    required this.report,
    required this.login,
  });
  final String heading;
  final String summary;
  final String report;
  final bool login;
  @override
  State<_WatchErrorDialog> createState() => _WatchErrorDialogState();
}

class _WatchErrorDialogState extends State<_WatchErrorDialog> {
  bool _details = false;
  String _copyLabel = '复制详情';

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.report));
      if (mounted) setState(() => _copyLabel = '已复制');
    } catch (_) {
      if (mounted) setState(() => _copyLabel = '复制失败，重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_details) {
      return WatchFlowPage(
        key: const ValueKey('detail'),
        title: '错误详情',
        children: [
          SelectableText(
            widget.report,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _copy, child: Text(_copyLabel)),
          TextButton(
            onPressed: () => setState(() => _details = false),
            child: const Text('收起详情'),
          ),
        ],
      );
    }
    final iconStyle = IconButton.styleFrom(
      minimumSize: const Size.square(48),
      shape: const CircleBorder(),
    );
    return WatchFlowPage(
      title: widget.heading,
      center: true,
      children: [
        Text(
          widget.summary,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            IconButton.filledTonal(
              style: iconStyle,
              tooltip: widget.login ? '暂不登录' : '查看详情',
              icon: Icon(
                widget.login ? Icons.close_rounded : Icons.info_outline_rounded,
              ),
              onPressed: () {
                if (widget.login) {
                  Navigator.pop(context, false);
                } else {
                  setState(() => _details = true);
                }
              },
            ),
            IconButton.filled(
              style: iconStyle,
              tooltip: widget.login ? '重新登录' : '知道了',
              icon: Icon(
                widget.login ? Icons.login_rounded : Icons.check_rounded,
              ),
              onPressed: () => Navigator.pop(context, widget.login),
            ),
          ],
        ),
        if (widget.login)
          TextButton(
            onPressed: () => setState(() => _details = true),
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurfaceVariant,
            ),
            child: const Text('查看详情'),
          ),
      ],
    );
  }
}

String errorMessage(dynamic error) {
  if (error == null) return '未知错误';
  if (error is String) return error;
  try {
    return error.toString();
  } catch (_) {
    return '未知错误';
  }
}

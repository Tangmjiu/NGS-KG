import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../watch/screens/login_screen.dart';
import '../watch/widgets/watch_player_primitives.dart';
import 'navigation.dart' as app;

final _visibleErrors = <(String, String, String?)>{};
final _sensitiveField = RegExp(
  r'''\b(?:authorization|bearer|(?:set-)?cookie|(?:access[_-]?|refresh[_-]?)?token|session(?:id)?|password|api[_-]?key|secret|user[_-]?id|dfid|mid|guid|serverdev|mac|phone|mobile|signature|sign)\b''',
  caseSensitive: false,
);

// 请求参数可携带完整 Cookie 和设备标识。只展示路径；含凭据的行整体遮蔽。
String _mask(String value) => value.split('\n').map((line) {
  final query = line.indexOf('?');
  final visible = query < 0 ? line : line.substring(0, query);
  if (_sensitiveField.hasMatch(visible)) return '［敏感信息已隐藏］';
  return query < 0 ? visible : '$visible?…';
}).join('\n');

/// 使用全局导航器显示错误。同一错误关闭后可再次显示。
void showErrorDialog({
  String title = '错误',
  required String message,
  String? errorCode,
  String? detail,
  bool showLogin = false,
}) {
  final ctx = app.navKey.currentContext;
  if (ctx == null) return;

  final login = showLogin || errorCode == 'API 20010' || errorCode == '20010';
  final key = login ? ('登录失效', '', null) : (title, message, errorCode);
  if (!_visibleErrors.add(key)) return;

  final heading = _mask(title);
  final reason = _mask(message).trim();
  final summary = reason.isEmpty ? '发生未知错误' : reason.split('\n').first;
  final report = [
    '标题: $heading',
    if (errorCode != null) '错误代码: ${_mask(errorCode)}',
    '原因: $reason',
    if (detail != null && detail.isNotEmpty) '详情: ${_mask(detail)}',
    'NGS-KG+',
  ].join('\n');

  showDialog<bool>(
    context: ctx,
    barrierDismissible: false,
    animationStyle: AnimationStyle.noAnimation,
    builder: (_) => _WatchErrorDialog(
      heading: heading,
      summary: summary,
      report: report,
      login: login,
    ),
  ).whenComplete(() => _visibleErrors.remove(key)).then((openLogin) {
    if (openLogin == true) {
      app.navKey.currentState?.push<void>(
        MaterialPageRoute<void>(builder: (_) => const WatchLoginScreen()),
      );
    }
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
  bool _expanded = false;
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.report));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final buttonStyle = TextButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    );
    return Dialog(
      insetPadding: EdgeInsets.zero,
      constraints: const BoxConstraints(maxWidth: 360),
      clipBehavior: Clip.antiAlias,
      child: WatchPlayerInsets(
        child: WatchSpringReveal(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.error_outline_rounded, color: colors.error),
                const SizedBox(height: 4),
                Semantics(
                  header: true,
                  child: Text(widget.heading, textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium),
                ),
                const SizedBox(height: 4),
                Text(widget.summary, maxLines: 3, overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                  onPressed: () => Navigator.pop(context, widget.login),
                  child: Text(widget.login ? '登录' : '我知道了', textAlign: TextAlign.center),
                ),
                TextButton(
                  style: buttonStyle,
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? '收起详情' : '查看详情', textAlign: TextAlign.center),
                ),
                if (_expanded)
                  WatchSpringReveal(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(color: colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: SelectableText(widget.report, style: theme.textTheme.bodySmall),
                          ),
                        ),
                        TextButton(style: buttonStyle, onPressed: _copy,
                            child: Text(_copied ? '已复制' : '复制详情', textAlign: TextAlign.center)),
                      ],
                    ),
                  ),
                TextButton(style: buttonStyle, onPressed: () => Navigator.pop(context),
                    child: const Text('取消')),
              ],
            ),
          ),
        ),
      ),
    );
  }
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

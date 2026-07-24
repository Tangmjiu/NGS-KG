import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/theme_assets.dart';

/// 支持作者弹窗
///
/// 返回 true 表示用户选择了"不再显示"。
Future<bool> showSupportMeDialog(BuildContext context,
    {bool autoPopup = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _SupportMeDialog(autoPopup: autoPopup),
  );
  return result ?? false;
}

class _SupportMeDialog extends StatefulWidget {
  final bool autoPopup;
  const _SupportMeDialog({this.autoPopup = false});

  @override
  State<_SupportMeDialog> createState() => _SupportMeDialogState();
}

class _SupportMeDialogState extends State<_SupportMeDialog> {
  bool _dontShowAgain = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ThemeImage(
            assetPath: ThemeAssets.supportMe,
            width: 120,
            height: 120,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          Text(
            '喜欢这个软件吗？前往 GitHub 点个 star 或者赞助作者',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          // 自动弹出模式显示"不再显示"选项
          if (widget.autoPopup) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 24,
                  child: Checkbox(
                    value: _dontShowAgain,
                    onChanged: (v) =>
                        setState(() => _dontShowAgain = v ?? true),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () =>
                      setState(() => _dontShowAgain = !_dontShowAgain),
                  child: const Text('不再显示',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _dontShowAgain),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            final navigator = Navigator.of(context);
            final uri = Uri.tryParse('https://www.ifdian.net/a/mjiutang');
            if (uri != null) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
            navigator.pop(false);
          },
          child: const Text('赞助作者'),
        ),
        FilledButton(
          onPressed: () {
            final navigator = Navigator.of(context);
            final uri = Uri.tryParse('https://github.com/Tangmjiu/NGS-KG/');
            if (uri != null) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
            navigator.pop(_dontShowAgain);
          },
          child: const Text('前往 GitHub'),
        ),
      ],
    );
  }
}

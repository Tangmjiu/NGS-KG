import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/announcement.dart';
import '../services/announcement_service.dart';
import '../utils/theme.dart';

/// 显示公告弹窗
Future<void> showAnnouncementDialog(
    BuildContext context, Announcement announcement) {
  return showM3Dialog(
    context: context,
    barrierDismissible: announcement.dismissible,
    builder: (ctx) => _AnnouncementDialogWidget(announcement: announcement),
  );
}

class _AnnouncementDialogWidget extends StatefulWidget {
  final Announcement announcement;

  const _AnnouncementDialogWidget({required this.announcement});

  @override
  State<_AnnouncementDialogWidget> createState() =>
      _AnnouncementDialogWidgetState();
}

class _AnnouncementDialogWidgetState extends State<_AnnouncementDialogWidget> {
  bool _dontShowAgain = false;

  Future<void> _handleLinkTap(String? href) async {
    if (href == null || href.isEmpty) return;

    Uri? uri;
    if (href.endsWith('.docx') ||
        href.endsWith('.doc') ||
        href.endsWith('.xlsx') ||
        href.endsWith('.pptx')) {
      // 使用微软 Office Online 预览服务免下载预览文档
      final previewUrl =
          'https://view.officeapps.live.com/op/view.aspx?src=${Uri.encodeComponent(href)}';
      uri = Uri.tryParse(previewUrl);
    } else {
      uri = Uri.tryParse(href);
    }

    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _onConfirm() {
    if (_dontShowAgain) {
      AnnouncementService.markAsRead(widget.announcement.id);
    } else if (widget.announcement.force) {
      // 强制弹出类型的公告，即使没勾选不再提示，点击确认也记为已读，除非下次服务器端更新了 ID
      AnnouncementService.markAsRead(widget.announcement.id);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: widget.announcement.dismissible,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 24,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.announcement.title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 发布时间
              Text(
                '发布于: ${_formatDateTime(widget.announcement.publishTime)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 12),

              // Markdown 正文内容
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: MarkdownBody(
                      data: widget.announcement.content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                        p: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: colorScheme.onSurface,
                        ),
                        h3: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                        code: theme.textTheme.bodyMedium?.copyWith(
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          fontFamily: 'monospace',
                        ),
                      ),
                      onTapLink: (text, href, title) => _handleLinkTap(href),
                    ),
                  ),
                ),
              ),

              // “不再提示” 勾选框
              if (!widget.announcement.force &&
                  widget.announcement.dismissible) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    setState(() {
                      _dontShowAgain = !_dontShowAgain;
                    });
                  },
                  borderRadius: AppShape.xs,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _dontShowAgain,
                        activeColor: colorScheme.primary,
                        onChanged: (val) {
                          setState(() {
                            _dontShowAgain = val ?? false;
                          });
                        },
                      ),
                      Text(
                        '不再提示',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          // 仅在可以 dismiss 的情况下显示关闭/稍后再说按钮
          if (widget.announcement.dismissible)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('稍后再说'),
            ),

          // 如果有 actionUrl 跳转按钮
          if (widget.announcement.actionUrl != null &&
              widget.announcement.actionUrl!.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('了解详情'),
              onPressed: () => _handleLinkTap(widget.announcement.actionUrl),
            ),

          FilledButton(
            onPressed: _onConfirm,
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

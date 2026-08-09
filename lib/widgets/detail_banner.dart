import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/theme.dart';

/// Music You 风格详情页 Banner 头:
/// 317px 封面大图背景 + surface 双层渐变晕染 + 底部信息区。
class DetailBanner extends StatelessWidget {
  final String? coverUrl;
  final String label;
  final String title;
  final String? subtitle;
  final String? description;
  final List<({String value, String label})> stats;
  final Widget actions;

  const DetailBanner({
    super.key,
    required this.coverUrl,
    required this.label,
    required this.title,
    this.subtitle,
    this.description,
    this.stats = const [],
    required this.actions,
  });

  static const double height = 317;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (coverUrl != null && coverUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: coverUrl!.contains('{size}')
                  ? coverUrl!.replaceAll('{size}', '800')
                  : coverUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) =>
                  Container(color: cs.surfaceContainerHighest),
            )
          else
            Container(color: cs.surfaceContainerHighest),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  cs.surface,
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  cs.surface,
                  Colors.transparent,
                  cs.surface.withValues(alpha: 0.7),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: tt.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(color: cs.primary),
                  ),
                ],
                if (stats.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var i = 0; i < stats.length; i++) ...[
                        if (i > 0)
                          Container(
                            width: 1,
                            height: 16,
                            margin: const EdgeInsets.symmetric(horizontal: 14),
                            color: cs.outlineVariant,
                          ),
                        Text(
                          stats[i].value,
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          stats[i].label,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                if (description != null && description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                actions,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Music You 风格"播放全部"按钮:
/// primary 12% 半透明底 + primary 文字 + 圆角 10。
class PlayAllButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  const PlayAllButton({super.key, this.onPressed, this.label = '播放全部'});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: cs.primary.withValues(alpha: 0.12),
        foregroundColor: cs.primary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      icon: const Icon(Icons.play_arrow_rounded, size: 20),
      label: Text(label),
    );
  }
}

/// Music You 风格"更多"圆形按钮: tertiary 12% alpha 背景。
class DetailMoreButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;

  const DetailMoreButton(
      {super.key, this.onPressed, this.icon = Icons.more_horiz_rounded});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: cs.tertiary.withValues(alpha: 0.12),
        foregroundColor: cs.onSurfaceVariant,
        fixedSize: const Size(40, 40),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

/// 描述/简介弹窗 (Music You 全宽圆角 24 弹窗)
void showDescriptionDialog(BuildContext context, String title, String content) {
  showM3Dialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Text(content, style: Theme.of(ctx).textTheme.bodySmall),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

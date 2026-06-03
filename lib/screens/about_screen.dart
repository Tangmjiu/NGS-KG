import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/theme_assets.dart';
import '../utils/about_config.dart';

/// 关于页面
///
/// 所有显示的文本均由 [AboutConfig] 提供，
/// 编译时可通过 --dart-define 覆盖（copyright 除外）。
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 32),

          // ── 图标 + 名称 + 版本 ──
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    ThemeAssets.icon,
                    width: 80,
                    height: 80,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child:
                          Icon(Icons.music_note, size: 40, color: cs.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(AboutConfig.appName,
                    style: tt.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('版本 ${AboutConfig.version}',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── 简介 ──
          Text(
            AboutConfig.description,
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),

          const SizedBox(height: 32),

          // ── 相关链接 ──
          _LinkSection(
            title: '相关链接',
            items: [
              _LinkItem(
                  icon: Icons.code,
                  label: 'GitHub 仓库',
                  url: AboutConfig.githubUrl),
              _LinkItem(
                  icon: Icons.api, label: '接口文档', url: AboutConfig.apiDocUrl),
              _LinkItem(
                  icon: Icons.history,
                  label: '更新日志',
                  url: AboutConfig.changelogUrl),
              _LinkItem(
                  icon: Icons.help_outline,
                  label: '常见问题',
                  url: AboutConfig.faqUrl),
              _LinkItem(
                  icon: Icons.palette_outlined,
                  label: '主题制作',
                  url: AboutConfig.themeUrl),
            ],
          ),

          const SizedBox(height: 32),

          // ── 版权信息（不可编辑） ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    children: [
                      const TextSpan(text: 'Copyright © 2025-2026 '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: GestureDetector(
                          onTap: () => launchUrl(
                            Uri.parse(AboutConfig.mjiutangUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: Text(
                            'mjiutang',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: '. All Rights Reserved'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AboutConfig.copyrightNotice,
                  textAlign: TextAlign.center,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── 链接区域 ───

class _LinkSection extends StatelessWidget {
  final String title;
  final List<_LinkItem> items;

  const _LinkSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  )),
        ),
        Card(
          elevation: 0,
          color: cs.surfaceContainerLow,
          child: Column(
            children: items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  if (i > 0)
                    Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: cs.outlineVariant),
                  ListTile(
                    leading:
                        Icon(item.icon, size: 20, color: cs.onSurfaceVariant),
                    title: Text(item.label,
                        style: Theme.of(context).textTheme.bodyMedium),
                    trailing: Icon(Icons.chevron_right,
                        size: 18, color: cs.onSurfaceVariant),
                    onTap: () => _onTap(context, item),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _onTap(BuildContext context, _LinkItem item) {
    final uri = Uri.tryParse(item.url);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _LinkItem {
  final IconData icon;
  final String label;
  final String url;

  const _LinkItem({
    required this.icon,
    required this.label,
    required this.url,
  });
}

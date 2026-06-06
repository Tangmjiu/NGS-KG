import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// 主题设置子页面
class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('主题')),
      body: Consumer<ThemeProvider>(
        builder: (_, tp, __) => ListView(
          children: [
            // ── 主题模式 ──
            const _GroupHeader('主题模式'),
            RadioListTile<ThemeMode>(
              title: const Text('跟随系统'),
              value: ThemeMode.system,
              groupValue: tp.themeMode,
              onChanged: (v) => tp.setThemeMode(v ?? ThemeMode.dark),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('浅色模式'),
              value: ThemeMode.light,
              groupValue: tp.themeMode,
              onChanged: (v) => tp.setThemeMode(v ?? ThemeMode.dark),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('深色模式'),
              value: ThemeMode.dark,
              groupValue: tp.themeMode,
              onChanged: (v) => tp.setThemeMode(v ?? ThemeMode.dark),
            ),
            const Divider(),

            // ── 强调色 ──
            const _GroupHeader('强调色'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('当前: ${tp.accentLabel}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          )),
                  const SizedBox(height: 12),
                  // 预设色圆点网格
                  Wrap(
                    spacing: 12,
                    runSpacing: 14,
                    children: [
                      ...kThemePresets.map((preset) => _ColorDot(
                            color: preset.lightPrimary,
                            selected: tp.accentKey == preset.key,
                            label: preset.label,
                            onTap: () => tp.setAccent(preset.key),
                          )),
                      // 自定义取色
                      _ColorDot(
                        color: tp.accentKey == 'custom'
                            ? tp.customColor
                            : Colors.grey,
                        selected: tp.accentKey == 'custom',
                        label: '取色',
                        icon: Icons.colorize,
                        onTap: () => _showColorPicker(context, tp),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),

            // ── Monet ──
            if (Platform.isAndroid) ...[
              const _GroupHeader('动态取色'),
              SwitchListTile(
                secondary: const Icon(Icons.wallpaper),
                title: const Text('Material You'),
                subtitle: const Text('跟随壁纸颜色自动适配（Android 12+）'),
                value: tp.useMonet,
                onChanged: (v) => tp.setUseMonet(v),
              ),
              const Divider(),
            ],

            // ── 主题包导入 ──
            const _GroupHeader('主题包'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tp.loadedTheme != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.check_circle, size: 18, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '当前: ${tp.loadedTheme!.name}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '作者: ${tp.loadedTheme!.author}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('移除主题包'),
                      onPressed: () {
                        tp.removeTheme();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已恢复默认主题')),
                        );
                      },
                    ),
                  ] else ...[
                    const Text('导入 ZIP 主题包可替换全部状态图片和主题色',
                        style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.file_open, size: 18),
                      label: const Text('导入 .zip 主题'),
                      onPressed: () async {
                        final ok = await tp.importTheme();
                        if (ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('主题包导入成功')),
                          );
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('导入失败或已取消')),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
            const Divider(),

            // ── 预览 ──
            const _GroupHeader('预览'),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _previewCard(context, Brightness.light),
                  const SizedBox(height: 12),
                  _previewCard(context, Brightness.dark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewCard(BuildContext context, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isDark ? '深色模式' : '浅色模式',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _previewChip(scheme.primary, scheme.onPrimary, 'Primary'),
              const SizedBox(width: 6),
              _previewChip(scheme.secondary, scheme.onSecondary, 'Secondary'),
              const SizedBox(width: 6),
              _previewChip(scheme.tertiary, scheme.onTertiary, 'Tertiary'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewChip(Color bg, Color fg, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }

  void _showColorPicker(BuildContext context, ThemeProvider tp) {
    Color picked = tp.customColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自定义取色'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: picked,
            onColorChanged: (c) => picked = c,
            pickerAreaHeightPercent: 0.7,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              tp.setCustomColor(picked);
              Navigator.pop(ctx);
            },
            child: const Text('应用'),
          ),
        ],
      ),
    );
  }
}

// ─── 组件 ───

class _GroupHeader extends StatelessWidget {
  final String title;
  const _GroupHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              )),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.selected,
    required this.label,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary, width: 3)
                  : Border.all(color: Colors.white24),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: color.withValues(alpha: 0.4), blurRadius: 8)
                    ]
                  : null,
            ),
            child: icon != null
                ? Icon(icon, color: Colors.white, size: 20)
                : null,
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                fontSize: 10,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              )),
        ],
      ),
    );
  }
}

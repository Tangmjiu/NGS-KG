import 'dart:io';

// ignore_for_file: deprecated_member_use
// TODO: 升级到 Flutter 稳定版提供 RadioGroup 后移除 RadioListTile 的 deprecated 忽略

import 'package:flutter/material.dart';
import '../utils/theme.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../models/theme_pack.dart';
import '../theme/theme_assets.dart';
import '../routes/app_routes.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 880;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('主题')),
      body: Consumer<ThemeProvider>(
        builder: (_, tp, __) => ListView(
          children: [
            const SizedBox(height: 8),
            // ── 水平主题包卡片列表 ──
            _PackCarousel(tp: tp),
            const Divider(height: 24),
            // ── 当前主题详情 ──
            _PackDetail(tp: tp),
            const Divider(height: 24),
            // ── 强调色 ──
            _AccentSection(tp: tp),
            const Divider(height: 8),
            // ── Monet ──
            _MonetSection(tp: tp),
            const Divider(height: 8),
            // ── 主题模式 ──
            _ThemeModeSection(tp: tp),
            const Divider(height: 8),
            // ── Hi-Res 金标 ──
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: const Icon(Icons.verified_outlined),
              title: const Text('显示 Hi-Res 金标'),
              subtitle: const Text('播放无损音质时在专辑封面上显示'),
              value: tp.showHiResBadge,
              onChanged: (v) => tp.setShowHiResBadge(v),
            ),
            const Divider(height: 8),
            // ── 歌词设置 ──
            ListTile(
              leading: const Icon(Icons.lyrics_outlined),
              title: const Text('歌词设置'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, AppRoutes.lyricSettings),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  水平主题包卡片列表
// ─────────────────────────────────────────────────────────────

class _PackCarousel extends StatelessWidget {
  final ThemeProvider tp;
  const _PackCarousel({required this.tp});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tp.packs.length + 1, // +1 for the "import" card
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          if (i == tp.packs.length) return _ImportCard(tp: tp);
          return _PackCard(
            pack: tp.packs[i],
            isSelected: tp.packs[i].id == tp.selectedPackId,
            onTap: () => tp.selectPack(tp.packs[i].id),
            onLongPress: tp.packs[i].isBuiltIn
                ? null
                : () => _confirmDelete(context, tp, tp.packs[i]),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, ThemeProvider tp, ThemePack pack) {
    showM3Dialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${pack.name}」'),
        content: const Text('此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              tp.deletePack(pack.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _PackCard extends StatefulWidget {
  final ThemePack pack;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _PackCard({
    required this.pack,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<_PackCard> createState() => _PackCardState();
}

class _PackCardState extends State<_PackCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          width: 135,
          child: Column(
            children: [
              // ── Preview / Icon ──
              Container(
                width: 135,
                height: 135,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: AppShape.lg,
                  border: Border.all(
                    color: widget.isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: widget.isSelected ? 2.5 : 1,
                  ),
                ),
                child: _buildPreview(context),
              ),
              const SizedBox(height: 8),
              // ── Name ──
              Text(
                widget.pack.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: widget.isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              // ── Author ──
              Text(
                widget.pack.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              // ── Current badge ──
              if (widget.isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: AppShape.sm,
                  ),
                  child: Text(
                    '当前',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    // 内置包 → 用软件默认 icon
    if (widget.pack.isBuiltIn) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Image.asset(ThemeAssets.icon, fit: BoxFit.contain),
      );
    }

    // 导入包有 preview → 显示
    if (widget.pack.previewPath != null) {
      return ClipRRect(
        borderRadius: AppShape.lg,
        child: Image.file(
          File(widget.pack.previewPath!),
          width: 135,
          height: 135,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackIcon(),
        ),
      );
    }

    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    return const Icon(Icons.archive_outlined, size: 48, color: Colors.grey);
  }
}

/// "导入"卡片
class _ImportCard extends StatelessWidget {
  final ThemeProvider tp;
  const _ImportCard({required this.tp});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final ok = await tp.importTheme();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ok ? '主题包导入成功' : '导入失败或已取消')),
          );
        }
      },
      child: SizedBox(
        width: 135,
        child: Column(
          children: [
            Container(
              width: 135,
              height: 135,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: AppShape.lg,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  style: BorderStyle.solid,
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 40, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 4),
                  Text('导入主题',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('导入 .zip',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            Text('主题包',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  当前主题详情
// ─────────────────────────────────────────────────────────────

class _PackDetail extends StatelessWidget {
  final ThemeProvider tp;
  const _PackDetail({required this.tp});

  @override
  Widget build(BuildContext context) {
    final pack = tp.currentPack;
    final tags = pack.featureTags;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pack.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(pack.author,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          if (pack.description != null) ...[
            const SizedBox(height: 4),
            Text(pack.description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
          const SizedBox(height: 12),
          // 覆盖清单
          if (tags.isNotEmpty) ...[
            Text('覆盖内容', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.primary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: tags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: AppShape.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, size: 14, color: cs.onPrimaryContainer),
                    const SizedBox(width: 4),
                    Text(tag, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onPrimaryContainer)),
                  ],
                ),
              )).toList(),
            ),
          ] else ...[
            Text('无自定义覆盖，使用默认值',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  强调色
// ─────────────────────────────────────────────────────────────

class _AccentSection extends StatelessWidget {
  final ThemeProvider tp;
  const _AccentSection({required this.tp});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('强调色', style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600, color: cs.primary)),
              const Spacer(),
              if (tp.hasAccentOverride)
                TextButton.icon(
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('清除覆盖'),
                  onPressed: tp.clearAccentOverride,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tp.hasAccentOverride
                ? '当前覆盖: ${tp.accentLabel}'
                : '使用主题包内置颜色',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
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
              _ColorDot(
                color: tp.accentKey == 'custom' ? tp.customColor : Colors.grey,
                selected: tp.accentKey == 'custom',
                label: '取色',
                icon: Icons.colorize,
                onTap: () => _showColorPicker(context, tp),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, ThemeProvider tp) {
    Color picked = tp.customColor;
    showM3Dialog(
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
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

// ─────────────────────────────────────────────────────────────
//  Material You
// ─────────────────────────────────────────────────────────────

class _MonetSection extends StatelessWidget {
  final ThemeProvider tp;
  const _MonetSection({required this.tp});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.wallpaper),
        title: const Text('Material You'),
        subtitle: const Text('跟随壁纸颜色自动适配（Android 12+）'),
        value: tp.useMonet,
        onChanged: (v) => tp.setUseMonet(v),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  主题模式
// ─────────────────────────────────────────────────────────────

class _ThemeModeSection extends StatelessWidget {
  final ThemeProvider tp;
  const _ThemeModeSection({required this.tp});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('主题模式', style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          )),
          const SizedBox(height: 4),
          RadioListTile<ThemeMode>(
            contentPadding: EdgeInsets.zero,
            title: const Text('跟随系统'),
            value: ThemeMode.system,
            groupValue: tp.themeMode,
            onChanged: (v) => tp.setThemeMode(v ?? ThemeMode.system),
          ),
          RadioListTile<ThemeMode>(
            contentPadding: EdgeInsets.zero,
            title: const Text('浅色模式'),
            value: ThemeMode.light,
            groupValue: tp.themeMode,
            onChanged: (v) => tp.setThemeMode(v ?? ThemeMode.system),
          ),
          RadioListTile<ThemeMode>(
            contentPadding: EdgeInsets.zero,
            title: const Text('深色模式'),
            value: ThemeMode.dark,
            groupValue: tp.themeMode,
            onChanged: (v) => tp.setThemeMode(v ?? ThemeMode.system),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  组件
// ─────────────────────────────────────────────────────────────

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
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                width: selected ? 3 : 1,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)]
                  : null,
            ),
            child:
                icon != null ? Icon(icon, color: Colors.white, size: 20) : null,
          ),
          const SizedBox(height: 4),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
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

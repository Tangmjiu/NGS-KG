// SPDX-License-Identifier: MIT
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import '../ui/app_ui.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../models/theme_pack.dart';
import '../routes/app_routes.dart';

class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  Brightness? _previewBrightness;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AppPageBody(
          child: Consumer<ThemeProvider>(
            builder: (context, theme, _) => ListView(
              padding: EdgeInsets.fromLTRB(
                  tokens.pagePadding,
                  16,
                  tokens.pagePadding,
                  40 + MediaQuery.paddingOf(context).bottom),
              children: [
                const AppPageHeader(
                  padding: EdgeInsets.zero,
                  title: '主题与外观',
                  subtitle: '找到属于你的音乐色彩',
                  showBack: true,
                ),
                SizedBox(height: tokens.sectionSpacing),
                const AppSectionHeader(
                    padding: EdgeInsets.zero,
                    title: '样式预览',
                    subtitle: '配色、字体和组件随设置实时更新'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in [
                      (Brightness.light, '浅色预览', Icons.light_mode_outlined),
                      (Brightness.dark, '深色预览', Icons.dark_mode_outlined),
                    ])
                      ChoiceChip(
                        avatar: Icon(option.$3, size: 18),
                        label: Text(option.$2),
                        selected: (_previewBrightness ??
                                Theme.of(context).brightness) ==
                            option.$1,
                        onSelected: (_) =>
                            setState(() => _previewBrightness = option.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                DynamicColorBuilder(builder: (light, dark) {
                  final brightness =
                      _previewBrightness ?? Theme.of(context).brightness;
                  final previewTheme = brightness == Brightness.light
                      ? theme.buildLightTheme(context, dynamicScheme: light)
                      : theme.buildDarkTheme(context, dynamicScheme: dark);
                  return Theme(
                      data: previewTheme, child: const _ThemePreview());
                }),
                SizedBox(height: tokens.sectionSpacing),
                const AppSectionHeader(
                    padding: EdgeInsets.zero,
                    title: '明暗模式',
                    subtitle: '选择应用的显示方式'),
                const SizedBox(height: 12),
                AppSurface(child: _ThemeModeSection(tp: theme)),
                SizedBox(height: tokens.sectionSpacing),
                AppSectionHeader(
                  padding: EdgeInsets.zero,
                  title: '主题包',
                  subtitle: '颜色、字体与个性资源',
                  actionLabel: '主题市场',
                  onAction: () =>
                      Navigator.pushNamed(context, AppRoutes.themeMarket),
                ),
                const SizedBox(height: 16),
                _PackCarousel(tp: theme),
                const SizedBox(height: 16),
                AppSurface(child: _PackDetail(tp: theme)),
                SizedBox(height: tokens.sectionSpacing),
                const AppSectionHeader(padding: EdgeInsets.zero, title: '主题色彩'),
                const SizedBox(height: 12),
                AppSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AccentSection(tp: theme),
                      const Divider(height: 32),
                      _MonetSection(tp: theme),
                    ],
                  ),
                ),
                SizedBox(height: tokens.sectionSpacing),
                const AppSectionHeader(
                    padding: EdgeInsets.zero, title: '播放器显示'),
                const SizedBox(height: 12),
                AppSurface(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.verified_outlined),
                      title: const Text('显示 Hi-Res 金标'),
                      subtitle: const Text('播放无损音质时显示封面标识'),
                      value: theme.showHiResBadge,
                      onChanged: theme.setShowHiResBadge,
                    ),
                    ListTile(
                      leading: const Icon(Icons.lyrics_outlined),
                      title: const Text('歌词设置'),
                      subtitle: const Text('字体、间距与显示效果'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.lyricSettings),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemePreview extends StatefulWidget {
  const _ThemePreview();

  @override
  State<_ThemePreview> createState() => _ThemePreviewState();
}

class _ThemePreviewState extends State<_ThemePreview> {
  bool _collected = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tokens = AppThemeTokens.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
                child: Text('音乐，让日常不同', style: theme.textTheme.titleLarge)),
            Icon(Icons.headphones_rounded, color: cs.primary),
          ]),
          const SizedBox(height: 6),
          Text('一张歌单，一段好时光',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(tokens.controlRadius),
                  ),
                  child: Icon(Icons.album_outlined,
                      color: cs.onPrimaryContainer, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('聆听日常', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('为喜欢的声音留一个位置',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                )),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => setState(() => _collected = !_collected),
              icon: Icon(_collected
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded),
              label: Text(_collected ? '已收藏 · 预览' : '收藏 · 预览'),
            ),
          ),
        ],
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
      height: 184 + MediaQuery.textScalerOf(context).scale(56),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
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
    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${pack.name}」'),
        content: const Text('此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
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

class _PackCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = AppThemeTokens.of(context).controlRadius;
    return Semantics(
      button: true,
      selected: isSelected,
      label: '主题包 ${pack.name}',
      child: SizedBox(
        width: 156,
        child: Material(
          color: isSelected ? cs.secondaryContainer : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 116,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(radius / 2),
                          child: _buildPreview(context),
                        ),
                        if (onLongPress != null)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton.filledTonal(
                              tooltip: '删除 ${pack.name}',
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18),
                              onPressed: onLongPress,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(pack.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(pack.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  if (isSelected)
                    Row(children: [
                      Icon(Icons.check_circle_rounded,
                          size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      Text('正在使用',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: cs.primary)),
                    ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    if (!pack.isBuiltIn && pack.previewPath != null) {
      return Image.file(
        File(pack.previewPath!),
        fit: BoxFit.cover,
        cacheWidth: 264,
        errorBuilder: (_, __, ___) => _palettePreview(context),
      );
    }
    return _palettePreview(context);
  }

  Widget _palettePreview(BuildContext context) {
    final colors = pack.lightScheme ?? Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                height: 8,
                width: 56,
                decoration: BoxDecoration(
                    color: colors.onSurface,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 12),
            Expanded(
              child: Row(children: [
                Expanded(
                    child: Container(
                        decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ))),
                const SizedBox(width: 8),
                Expanded(
                    child: Container(
                        decoration: BoxDecoration(
                  color: colors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ))),
              ]),
            ),
            const SizedBox(height: 10),
            Container(
                height: 10,
                width: 36,
                decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(5))),
          ],
        ),
      ),
    );
  }
}

/// "导入"卡片
class _ImportCard extends StatelessWidget {
  final ThemeProvider tp;
  const _ImportCard({required this.tp});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 156,
      child: AppSurface(
        onTap: () async {
          final ok = await tp.importTheme();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ok ? '主题包导入成功' : '导入失败或已取消'),
            ));
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, size: 36, color: cs.primary),
            const SizedBox(height: 16),
            Text('导入主题', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text('选择 ZIP 主题包',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
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
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pack.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(pack.author,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
          if (pack.description != null) ...[
            const SizedBox(height: 4),
            Text(pack.description!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ],
          const SizedBox(height: 12),
          // 覆盖清单
          if (tags.isNotEmpty) ...[
            Text('覆盖内容',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: cs.primary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: tags
                  .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: AppShape.sm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check,
                                size: 14, color: cs.onPrimaryContainer),
                            const SizedBox(width: 4),
                            Text(tag,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: cs.onPrimaryContainer)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ] else ...[
            Text('无自定义覆盖，使用默认值',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
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
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text('强调色', style: Theme.of(context).textTheme.titleMedium),
              if (tp.hasAccentOverride)
                TextButton.icon(
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('恢复主题配色'),
                  onPressed: tp.clearAccentOverride,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tp.hasAccentOverride ? '当前覆盖: ${tp.accentLabel}' : '使用主题包内置颜色',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
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
                color: tp.accentKey == 'custom'
                    ? tp.customColor
                    : cs.outlineVariant,
                selected: tp.accentKey == 'custom',
                label: '自定义',
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
    showAppDialog(
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
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
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
      padding: EdgeInsets.zero,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.wallpaper),
        title: const Text('跟随壁纸配色'),
        subtitle: const Text('使用系统动态主题色（Android 12+）'),
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
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in [
            (ThemeMode.system, '跟随系统', Icons.brightness_auto_outlined),
            (ThemeMode.light, '浅色', Icons.light_mode_outlined),
            (ThemeMode.dark, '深色', Icons.dark_mode_outlined),
          ])
            ChoiceChip(
              avatar: Icon(option.$3, size: 18),
              label: Text(option.$2),
              selected: tp.themeMode == option.$1,
              onSelected: (_) => tp.setThemeMode(option.$1),
            ),
        ],
      );
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
    final cs = Theme.of(context).colorScheme;
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label主题色',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? cs.onSurface : cs.outlineVariant,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: icon != null || selected
                    ? Icon(icon ?? Icons.check_rounded,
                        color: onColor, size: 22)
                    : null,
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected ? cs.primary : cs.onSurfaceVariant,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                      )),
            ],
          ),
        ),
      ),
    );
  }
}

// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../models/theme_pack.dart';
import '../theme/app_theme.dart';
import 'components/app_components.dart';
import 'components/app_loading_indicator.dart';
import 'components/app_primary_button.dart';

@Preview(name: '浏览组件 · 浅色', size: Size(390, 844))
Widget previewBrowseLight() => const _BrowsePreview(dark: false);

@Preview(name: '浏览组件 · 深色', size: Size(390, 844))
Widget previewBrowseDark() => const _BrowsePreview(dark: true);

@Preview(name: '浏览组件 · 宽屏', size: Size(840, 800))
Widget previewBrowseWide() => const _BrowsePreview(dark: false);

@Preview(name: '加载状态 · 浅色', size: Size(240, 160))
Widget previewLoadingLight() => MaterialApp(
      theme: AppTheme.build(ngsNagisa.lightScheme!, ngsNagisa),
      home: const Scaffold(body: Center(child: AppLoadingIndicator())),
    );

@Preview(name: '加载状态 · 深色', size: Size(240, 160))
Widget previewLoadingDark() => MaterialApp(
      theme: AppTheme.build(ngsNagisa.darkScheme!, ngsNagisa),
      home: const Scaffold(body: Center(child: AppLoadingIndicator())),
    );

@Preview(name: '空状态 · 小屏大字', size: Size(320, 420))
Widget previewEmptyState() => MaterialApp(
      theme: AppTheme.build(ngsNagisa.lightScheme!, ngsNagisa),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: EmptyStateContent(
          icon: Icons.queue_music_rounded,
          title: '歌单里还没有歌曲',
          message: '找到喜欢的音乐后，可以添加到这里。',
          action: FilledButton(onPressed: () {}, child: const Text('发现音乐')),
        ),
      ),
    );

class _BrowsePreview extends StatelessWidget {
  final bool dark;
  const _BrowsePreview({required this.dark});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(ngsNagisa.lightScheme!, ngsNagisa),
        darkTheme: AppTheme.build(ngsNagisa.darkScheme!, ngsNagisa),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: const Scaffold(body: SafeArea(child: _PreviewContent())),
      );
}

class _PreviewContent extends StatefulWidget {
  const _PreviewContent();
  @override
  State<_PreviewContent> createState() => _PreviewContentState();
}

class _PreviewContentState extends State<_PreviewContent> {
  bool _playing = false;
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppPageBody(
      child: ListView(
        children: [
          AppPageHeader(
            title: '发现',
            subtitle: '为此刻的你，找一点新鲜声音',
            actions: [
              IconButton.filledTonal(
                tooltip: '设置',
                onPressed: () {},
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppSurface(
              color: colors.secondaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sensors_rounded, size: 32),
                  const SizedBox(height: 24),
                  Text('私人 FM',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  const Text('从熟悉的旋律，到还没遇见的喜欢。'),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      AppPrimaryButton(
                        onPressed: () => setState(() => _playing = !_playing),
                        icon: _playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        label: _playing ? '暂停' : '开始收听',
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: _liked ? '取消喜欢' : '喜欢',
                        onPressed: () => setState(() => _liked = !_liked),
                        icon: Icon(_liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AppSectionHeader(title: '你的音乐', actionLabel: '查看全部', onAction: () {}),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                    width: 160,
                    child: AppShortcutCard(
                      icon: Icons.favorite_outline,
                      title: '我喜欢的',
                      subtitle: '收藏每一次心动',
                      onTap: () {},
                    )),
                SizedBox(
                    width: 160,
                    child: AppShortcutCard(
                      icon: Icons.folder_outlined,
                      title: '本地音乐',
                      subtitle: '随时随地收听',
                      onTap: () {},
                    )),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

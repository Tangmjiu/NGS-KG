// SPDX-License-Identifier: MIT
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/theme_market_listing.dart';
import '../providers/theme_provider.dart';
import '../services/market_service.dart';
import '../ui/app_ui.dart';
import '../utils/logger.dart';

class ThemeMarketScreen extends StatefulWidget {
  const ThemeMarketScreen({super.key});

  @override
  State<ThemeMarketScreen> createState() => _ThemeMarketScreenState();
}

enum _InstallStage { downloading, installing, applying }

class _ThemeMarketScreenState extends State<ThemeMarketScreen> {
  List<ThemeMarketListing> _listings = [];
  Set<String> _installedIds = {};
  final Map<String, _InstallStage> _operations = {};
  final Map<String, CancelToken> _downloads = {};
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final token in _downloads.values) {
      if (!token.isCancelled) token.cancel();
    }
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh && (_loading || _refreshing)) return;
    setState(() {
      _loading = !refresh;
      _refreshing = refresh;
      _error = null;
    });
    try {
      final results = await Future.wait([
        refresh
            ? MarketService.refreshRegistry()
            : MarketService.fetchRegistry(),
        MarketService.getInstalledIds(),
      ]);
      if (!mounted) return;
      setState(() {
        _listings = results[0] as List<ThemeMarketListing>;
        _installedIds = results[1] as Set<String>;
      });
    } catch (error, stack) {
      Log.e('ThemeMarketScreen', 'Cannot load themes', error, stack);
      if (mounted) setState(() => _error = '加载失败，请检查网络后重试。');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _install(ThemeMarketListing listing) async {
    if (_operations.containsKey(listing.id)) return;
    final theme = context.read<ThemeProvider>();
    final cancelToken = CancelToken();
    setState(() {
      _operations[listing.id] = _InstallStage.downloading;
      _downloads[listing.id] = cancelToken;
    });
    try {
      final bytes = await MarketService.downloadTheme(listing.downloadUrl,
          cancelToken: cancelToken);
      if (!mounted) return;
      if (cancelToken.isCancelled) {
        _message('已取消「${listing.name}」的下载');
        return;
      }
      if (bytes == null || bytes.isEmpty) {
        _message('下载失败，请重试');
        return;
      }
      setState(() => _operations[listing.id] = _InstallStage.installing);
      _downloads.remove(listing.id);
      final pack = await MarketService.installTheme(bytes, '${listing.id}.zip');
      if (pack == null) {
        _message('安装失败，主题包格式不正确');
        return;
      }
      // 安装写盘已完成时，即使离开市场，也同步应用中可用的主题列表。
      theme.addMarketPack(pack);
      if (!mounted) return;
      setState(() => _installedIds.add(listing.id));
      final apply = await showAppDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('安装完成'),
          content: Text('「${listing.name}」已准备就绪。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('稍后再说')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('立即应用')),
          ],
        ),
      );
      if (apply == true && mounted) {
        setState(() => _operations[listing.id] = _InstallStage.applying);
        await theme.selectPack(pack.id);
        if (mounted) Navigator.pop(context);
      }
    } catch (error, stack) {
      Log.e('ThemeMarketScreen', 'Cannot install theme', error, stack);
      _message('主题安装未完成，请重试');
    } finally {
      _downloads.remove(listing.id);
      if (mounted) setState(() => _operations.remove(listing.id));
    }
  }

  Future<void> _apply(ThemeMarketListing listing) async {
    if (_operations.containsKey(listing.id)) return;
    setState(() => _operations[listing.id] = _InstallStage.applying);
    try {
      await context.read<ThemeProvider>().selectPack(listing.id);
      _message('已应用「${listing.name}」');
    } catch (error, stack) {
      Log.e('ThemeMarketScreen', 'Cannot apply theme', error, stack);
      _message('应用失败，请重试');
    } finally {
      if (mounted) setState(() => _operations.remove(listing.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final theme = context.watch<ThemeProvider>();
    final available = theme.packs.map((pack) => pack.id).toSet();
    return Scaffold(
      body: SafeArea(
          bottom: false,
          child: AppPageBody(
              child: RefreshIndicator(
            onRefresh: () => _load(refresh: true),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                    child: AppPageHeader(
                  title: '主题市场',
                  subtitle: '发现新的配色、字体与音乐氛围',
                  showBack: true,
                  actions: [
                    IconButton(
                      tooltip: '刷新主题',
                      onPressed: _loading || _refreshing
                          ? null
                          : () => _load(refresh: true),
                      icon: _refreshing
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh_rounded),
                    )
                  ],
                )),
                if (_loading)
                  const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: AppLoadingIndicator()))
                else if (_error != null)
                  SliverToBoxAdapter(
                      child: AppEmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: '暂时无法加载主题',
                    message: _error,
                    action: FilledButton.tonalIcon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('重试')),
                  ))
                else if (_listings.isEmpty)
                  SliverToBoxAdapter(
                      child: AppEmptyState(
                    icon: Icons.palette_outlined,
                    title: '暂无可用主题',
                    message: '稍后再来看看，或在主题设置中导入本地主题包。',
                    action: FilledButton.tonalIcon(
                        onPressed: () => _load(refresh: true),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('刷新')),
                  ))
                else
                  SliverPadding(
                    padding:
                        EdgeInsets.symmetric(horizontal: tokens.pagePadding),
                    sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                      final listing = _listings[index];
                      final installed = _installedIds.contains(listing.id) ||
                          available.contains(listing.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _ThemeMarketCard(
                          key: ValueKey(listing.id),
                          listing: listing,
                          installed: installed,
                          active: theme.selectedPackId == listing.id,
                          canApply: available.contains(listing.id),
                          stage: _operations[listing.id],
                          onInstall: () => _install(listing),
                          onApply: () => _apply(listing),
                          onCancel: () => _downloads[listing.id]?.cancel(),
                        ),
                      );
                    }, childCount: _listings.length)),
                  ),
                SliverToBoxAdapter(
                    child: SizedBox(
                        height: AppChrome.miniPlayerExtent(context) +
                            MediaQuery.paddingOf(context).bottom +
                            32)),
              ],
            ),
          ))),
    );
  }
}

class _ThemeMarketCard extends StatelessWidget {
  final ThemeMarketListing listing;
  final bool installed;
  final bool active;
  final bool canApply;
  final _InstallStage? stage;
  final VoidCallback onInstall;
  final VoidCallback onApply;
  final VoidCallback onCancel;

  const _ThemeMarketCard({
    super.key,
    required this.listing,
    required this.installed,
    required this.active,
    required this.canApply,
    required this.stage,
    required this.onInstall,
    required this.onApply,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppThemeTokens.of(context);
    return AppSurface(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 620 &&
            MediaQuery.textScalerOf(context).scale(14) <= 21;
        final preview = ClipRRect(
          borderRadius: BorderRadius.circular(tokens.controlRadius),
          child: AspectRatio(
              aspectRatio: 1,
              child: listing.previewUrl.isEmpty
                  ? _previewFallback(context)
                  : CachedNetworkImage(
                      imageUrl: listing.previewUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 640,
                      placeholder: (_, __) => _previewFallback(context),
                      errorWidget: (_, __, ___) => _previewFallback(context),
                    )),
        );
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(listing.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('v${listing.version} · ${listing.author}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (listing.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(listing.description,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis),
            ],
            if (listing.tags.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: listing.tags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius:
                                BorderRadius.circular(tokens.controlRadius),
                          ),
                          child: Text(tag,
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color:
                                      theme.colorScheme.onSecondaryContainer)),
                        ),
                      )
                      .toList()),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(listing.formattedSize,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                if (installed) _StatusChip(label: active ? '使用中' : '已安装'),
              ],
            ),
            const SizedBox(height: 12),
            if (stage != null)
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const LinearProgressIndicator(),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                        switch (stage!) {
                          _InstallStage.downloading => '正在下载…',
                          _InstallStage.installing => '正在安装…',
                          _InstallStage.applying => '正在应用…',
                        },
                        style: theme.textTheme.bodyMedium),
                    if (stage == _InstallStage.downloading)
                      TextButton.icon(
                          onPressed: onCancel,
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('取消下载')),
                  ],
                ),
              ])
            else
              Wrap(spacing: 12, runSpacing: 8, children: [
                if (!installed || !canApply)
                  FilledButton.icon(
                      onPressed: onInstall,
                      icon: const Icon(Icons.download_rounded),
                      label: Text(installed ? '重新安装' : '安装主题'))
                else ...[
                  FilledButton.tonalIcon(
                      onPressed: active ? null : onApply,
                      icon: Icon(active
                          ? Icons.check_rounded
                          : Icons.palette_outlined),
                      label: Text(active ? '正在使用' : '应用主题')),
                  TextButton(onPressed: onInstall, child: const Text('重新安装')),
                ],
              ]),
          ],
        );
        if (horizontal) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 200, child: preview),
            const SizedBox(width: 24),
            Expanded(child: details),
          ]);
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              preview,
              const SizedBox(height: 20),
              details,
            ]);
      }),
    );
  }

  Widget _previewFallback(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
            child: Icon(Icons.palette_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _StatusChip extends StatelessWidget {
  final String label;
  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius:
              BorderRadius.circular(AppThemeTokens.of(context).controlRadius)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline_rounded,
            size: 16, color: theme.colorScheme.onPrimaryContainer),
        const SizedBox(width: 6),
        Flexible(
            child: Text(label,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.onPrimaryContainer))),
      ]),
    );
  }
}

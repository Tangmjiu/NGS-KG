import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/theme_market_listing.dart';
import '../providers/theme_provider.dart';
import '../services/market_service.dart';
import '../utils/logger.dart';
import '../utils/responsive.dart';
import '../widgets/desktop_route_wrapper.dart';
import '../widgets/staggered_fade_slide.dart';

class ThemeMarketScreen extends StatefulWidget {
  const ThemeMarketScreen({super.key});

  @override
  State<ThemeMarketScreen> createState() => _ThemeMarketScreenState();
}

class _ThemeMarketScreenState extends State<ThemeMarketScreen> {
  List<ThemeMarketListing> _listings = [];
  Set<String> _installedIds = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        MarketService.fetchRegistry(),
        MarketService.getInstalledIds(),
      ]);
      if (!mounted) return;
      setState(() {
        _listings = results[0] as List<ThemeMarketListing>;
        _installedIds = results[1] as Set<String>;
        _loading = false;
      });
    } catch (e, s) {
      Log.e('ThemeMarketScreen', 'load failed', e, s);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载失败，请检查网络后重试';
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait([
        MarketService.refreshRegistry(),
        MarketService.getInstalledIds(),
      ]);
      if (!mounted) return;
      setState(() {
        _listings = results[0] as List<ThemeMarketListing>;
        _installedIds = results[1] as Set<String>;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '刷新失败');
    }
  }

  Future<void> _install(ThemeMarketListing listing) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('正在下载…'),
        duration: const Duration(seconds: 30),
        action: SnackBarAction(
          label: '取消',
          onPressed: () {},
        ),
      ),
    );

    final bytes = await MarketService.downloadTheme(listing.downloadUrl);
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('下载失败，请重试')),
      );
      return;
    }

    final pack = await MarketService.installTheme(bytes, '${listing.id}.zip');
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (pack == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('安装失败，主题包格式不正确')),
      );
      return;
    }

    if (!mounted) return;
    final tp = context.read<ThemeProvider>();
    tp.addMarketPack(pack);

    setState(() => _installedIds.add(listing.id));

    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('安装完成'),
        content: Text('「${listing.name}」已下载'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('稍后再说'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('立即应用'),
          ),
        ],
      ),
    );

    if (apply == true && mounted) {
      await tp.selectPack(pack.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      mobile: (_) => _buildMobile(),
      tablet: (_) => _buildMobile(),
      desktop: (_) => _buildDesktop(),
    );
  }

  Widget _buildMobile() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('主题市场'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildDesktop() {
    return DesktopRouteWrapper(
      title: '主题市场',
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              onPressed: _load,
            ),
          ],
        ),
      );
    }

    if (_listings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('暂无可用主题', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('刷新'),
              onPressed: _refresh,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: _listings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => StaggeredFadeSlide(
          index: i,
          slideOffset: 12,
          staggerMs: 30,
          child: _ThemeMarketCard(
            listing: _listings[i],
            installed: _installedIds.contains(_listings[i].id),
            onInstall: () => _install(_listings[i]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  主题市场卡片
// ─────────────────────────────────────────────────────────────

class _ThemeMarketCard extends StatelessWidget {
  final ThemeMarketListing listing;
  final bool installed;
  final VoidCallback onInstall;

  const _ThemeMarketCard({
    required this.listing,
    required this.installed,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 120,
                height: 120,
                child: CachedNetworkImage(
                  imageUrl: listing.previewUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: cs.surfaceContainerHighest,
                    child: const Icon(Icons.image_outlined, color: Colors.grey),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: cs.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.name,
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'v${listing.version} · ${listing.author}',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    listing.description,
                    style: tt.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (listing.tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: listing.tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _tagColor(cs, listing.tagColorIndex).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 11,
                            color: _tagColor(cs, listing.tagColorIndex),
                          ),
                        ),
                      )).toList(),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        listing.formattedSize,
                        style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const Spacer(),
                      if (installed)
                        _StatusChip(
                          label: '已安装',
                          icon: Icons.check_circle,
                          color: Colors.green,
                        )
                      else
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('安装'),
                          onPressed: onInstall,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _tagColor(ColorScheme cs, int index) {
    const colors = [
      Color(0xFF7C3AED),
      Color(0xFF0891B2),
      Color(0xFF059669),
      Color(0xFFD97706),
      Color(0xFFDC2626),
      Color(0xFFDB2777),
      Color(0xFF4F46E5),
    ];
    return colors[index % colors.length];
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

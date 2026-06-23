import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/discover_provider.dart';
import '../utils/responsive.dart';
import '../widgets/shell_navigation_scope.dart';
import 'discover/sections/discover_quick_actions.dart';
import 'recommended_playlists_screen.dart';
import 'rank_detail_screen.dart';
import 'fm_screen.dart';
import 'discover/sections/discover_section_header.dart';
import 'discover/sections/discover_playlist_row.dart';
import 'discover/sections/discover_rank_row.dart';
import 'discover/sections/discover_song_row.dart';
import 'discover/sections/discover_album_row.dart';
import 'discover/sections/discover_scene_row.dart';
import 'discover/sections/discover_ip_row.dart';
import 'discover/sections/discover_fm_row.dart';
import 'discover/sections/discover_personal_fm_row.dart';

/// 发现页
///
/// 重构后：薄编排层 + Provider 状态管理 + 独立 Section Widget
/// 原来 819 行单体文件 → ~200 行编排层 + 11 个独立 Widget
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  @override
  void initState() {
    super.initState();
    // 首次加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiscoverProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      desktop: (_) => _buildDesktop(),
      mobile: (_) => _buildMobile(),
      tablet: (_) => _buildMobile(),
    );
  }

  Widget _buildDesktop() {
    final provider = context.watch<DiscoverProvider>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () => provider.loadAll(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        children: [
          // ── Title ──
          Text('发现',
              style: tt.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          if (provider.loading)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (provider.error != null)
              _buildErrorState(cs, tt, provider)
            else ...[
              DiscoverQuickActions(rankList: provider.rankList),
              const SizedBox(height: 16),

              if (provider.hasPlaylists) ...[
                DiscoverSectionHeader(
                  title: '推荐歌单',
                  onViewAll: () => ShellNavigationScope.navigate(
                    context,
                    routeName: '/recommended/playlists',
                    shellPageBuilder: () => const RecommendedPlaylistsScreen(),
                  ),
                ),
                DiscoverPlaylistRow(playlists: provider.topPlaylists),
                const SizedBox(height: 8),
              ],

              if (provider.hasRanks) ...[
                DiscoverSectionHeader(
                  title: '热门榜单',
                  onViewAll: () => _showRankList(provider.rankList),
                ),
                DiscoverRankRow(ranks: provider.rankList),
                const SizedBox(height: 8),
              ],

              if (provider.hasPersonalFm || !provider.loading) ...[
                DiscoverPersonalFmRow(
                  songs: provider.personalFmSongs,
                  onRefresh: () => provider.loadAll(),
                ),
                const SizedBox(height: 8),
              ],

              if (provider.hasTopSongs) ...[
                const DiscoverSectionHeader(title: '新歌速递'),
                DiscoverSongRow(songs: provider.topSongs),
                const SizedBox(height: 8),
              ],

              if (provider.hasTopAlbums) ...[
                const DiscoverSectionHeader(title: '新碟上架'),
                DiscoverAlbumRow(albums: provider.topAlbums),
                const SizedBox(height: 8),
              ],

              if (provider.hasScenes) ...[
                const DiscoverSectionHeader(title: '场景音乐'),
                DiscoverSceneRow(scenes: provider.sceneCategories),
                const SizedBox(height: 8),
              ],

              if (provider.hasIp) ...[
                const DiscoverSectionHeader(title: '编辑精选'),
                DiscoverIpRow(ipList: provider.ipList),
                const SizedBox(height: 8),
              ],

              if (provider.hasFm) ...[
                DiscoverSectionHeader(
                  title: '电台推荐',
                  onViewAll: () => ShellNavigationScope.navigate(
                    context,
                    routeName: '/fm',
                    shellPageBuilder: () => const FmScreen(),
                  ),
                ),
                DiscoverFmRow(fmList: provider.fmList),
              ],
            ],
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme cs, TextTheme tt, DiscoverProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 8),
            Text('加载失败',
                style: tt.titleMedium?.copyWith(color: cs.error)),
            const SizedBox(height: 4),
            Text(provider.error!,
                style: tt.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => provider.loadAll(),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobile() {
    final provider = context.watch<DiscoverProvider>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () => provider.loadAll(),
      child: CustomScrollView(
        slivers: [
          // ── Title ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 20,
                20,
                4,
              ),
              child: Text(
                '发现',
                style: tt.headlineLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          if (provider.loading)
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else ...[
            // ── Error state ──
            if (provider.error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: cs.error),
                        const SizedBox(height: 8),
                        Text('加载失败',
                            style: tt.titleMedium
                                ?.copyWith(color: cs.error)),
                        const SizedBox(height: 4),
                        Text(provider.error!,
                            style: tt.bodySmall,
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () => provider.loadAll(),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              // ── Quick actions ──
              SliverToBoxAdapter(
                child: DiscoverQuickActions(rankList: provider.rankList),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // ── 推荐歌单 ──
              if (provider.hasPlaylists) ...[
                SliverToBoxAdapter(
                  child: DiscoverSectionHeader(
                    title: '推荐歌单',
                    onViewAll: () => ShellNavigationScope.navigate(
                      context,
                      routeName: '/recommended/playlists',
                      shellPageBuilder: () => const RecommendedPlaylistsScreen(),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: DiscoverPlaylistRow(playlists: provider.topPlaylists),
                ),
              ],

              // ── 热门榜单 ──
              if (provider.hasRanks) ...[
                SliverToBoxAdapter(
                  child: DiscoverSectionHeader(
                    title: '热门榜单',
                    onViewAll: () => _showRankList(provider.rankList),
                  ),
                ),
                SliverToBoxAdapter(
                  child: DiscoverRankRow(ranks: provider.rankList),
                ),
              ],

              // ── FM ──
              if (provider.hasPersonalFm || !provider.loading) ...[
                SliverToBoxAdapter(
                  child: DiscoverPersonalFmRow(
                    songs: provider.personalFmSongs,
                    onRefresh: () => provider.loadAll(),
                  ),
                ),
              ],

              // ── 新歌速递 ──
              if (provider.hasTopSongs) ...[
                const SliverToBoxAdapter(
                  child: DiscoverSectionHeader(title: '新歌速递'),
                ),
                SliverToBoxAdapter(
                  child: DiscoverSongRow(songs: provider.topSongs),
                ),
              ],

              // ── 新碟上架 ──
              if (provider.hasTopAlbums) ...[
                const SliverToBoxAdapter(
                  child: DiscoverSectionHeader(title: '新碟上架'),
                ),
                SliverToBoxAdapter(
                  child: DiscoverAlbumRow(albums: provider.topAlbums),
                ),
              ],

              // ── 场景音乐 ──
              if (provider.hasScenes) ...[
                const SliverToBoxAdapter(
                  child: DiscoverSectionHeader(title: '场景音乐'),
                ),
                SliverToBoxAdapter(
                  child: DiscoverSceneRow(
                      scenes: provider.sceneCategories),
                ),
              ],

              // ── 编辑精选 ──
              if (provider.hasIp) ...[
                const SliverToBoxAdapter(
                  child: DiscoverSectionHeader(title: '编辑精选'),
                ),
                SliverToBoxAdapter(
                  child: DiscoverIpRow(ipList: provider.ipList),
                ),
              ],

              // ── 电台推荐 ──
              if (provider.hasFm) ...[
                SliverToBoxAdapter(
                  child: DiscoverSectionHeader(
                    title: '电台推荐',
                    onViewAll: () => ShellNavigationScope.navigate(
                      context,
                      routeName: '/fm',
                      shellPageBuilder: () => const FmScreen(),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: DiscoverFmRow(fmList: provider.fmList),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ],
        ],
      ),
    );
  }

  void _showRankList(List rankList) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        // SafeArea 底部内边距不计入可用高度，否则内容溢出
        final availableHeight = MediaQuery.of(context).size.height * 0.55
            - MediaQuery.of(context).padding.bottom;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('热门榜单',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: availableHeight,
                ),
                child: ListView.builder(
                itemCount: rankList.length,
                itemBuilder: (_, i) {
                  final r = rankList[i];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: r.coverUrl != null
                          ? Image.network(r.coverUrl!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _rankPlaceholder())
                          : _rankPlaceholder(),
                    ),
                    title: Text(r.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(context);
                      ShellNavigationScope.navigate(
                        context,
                        routeName: '/rank/detail',
                        arguments: {'id': r.id, 'name': r.name},
                        shellPageBuilder: () => RankDetailScreen(
                          rankId: r.id,
                          rankName: r.name,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
    );
  }

  Widget _rankPlaceholder() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      color: cs.surfaceContainerHighest,
      child: const Icon(Icons.music_note),
    );
  }
}

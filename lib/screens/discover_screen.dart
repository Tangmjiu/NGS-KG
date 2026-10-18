// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rank_entry.dart';
import '../providers/discover_provider.dart';
import '../ui/app_ui.dart';
import '../ui/components/player_bottom_padding.dart';
import 'discover/sections/discover_album_row.dart';
import 'discover/sections/discover_fm_row.dart';
import 'discover/sections/discover_ip_row.dart';
import 'discover/sections/discover_media_rail.dart';
import 'discover/sections/discover_personal_fm_row.dart';
import 'discover/sections/discover_playlist_row.dart';
import 'discover/sections/discover_quick_actions.dart';
import 'discover/sections/discover_rank_row.dart';
import 'discover/sections/discover_scene_row.dart';
import 'discover/sections/discover_section_header.dart';
import 'discover/sections/discover_song_row.dart';

class DiscoverScreen extends StatefulWidget {
  final int privateFmFocusRequest;

  const DiscoverScreen({super.key, this.privateFmFocusRequest = 0});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _privateFmKey = GlobalKey();

  void _focusPrivateFm() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _privateFmKey.currentContext;
      if (mounted && target != null) {
        Scrollable.ensureVisible(target,
            duration: AppMotion.dMedium3, alignment: 0.08);
      }
    });
  }

  @override
  void didUpdateWidget(covariant DiscoverScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.privateFmFocusRequest != widget.privateFmFocusRequest) {
      _focusPrivateFm();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.privateFmFocusRequest > 0) _focusPrivateFm();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DiscoverProvider>().ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DiscoverProvider>();
    final tokens = AppThemeTokens.of(context);
    return AppPageBody(
      child: RefreshIndicator(
        onRefresh: () => provider.loadAll(),
        child: CustomScrollView(
          key: const PageStorageKey('discover_feed'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top + 12),
                child: AppPageHeader(
                  title: '发现',
                  subtitle: '熟悉的旋律，意想不到的相遇',
                  actions: [
                    IconButton.filledTonal(
                      tooltip: '设置',
                      onPressed: () =>
                          Navigator.pushNamed(context, '/settings'),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: DiscoverQuickActions(rankList: provider.rankList),
            ),
            const SliverToBoxAdapter(
              child: DiscoverSectionHeader(
                title: '专属于你的频道',
                subtitle: '私人 FM · 随心听下去',
              ),
            ),
            SliverToBoxAdapter(
              child: DiscoverPersonalFmRow(key: _privateFmKey),
            ),
            if (provider.loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: AppLoadingIndicator()),
                ),
              ),
            if (provider.error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: tokens.pagePadding),
                  child: AppEmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: '推荐暂时未能加载',
                    message: '检查网络后重试，或继续收听你的音乐。',
                    action: FilledButton.tonalIcon(
                      onPressed: () => provider.loadAll(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('重试'),
                    ),
                  ),
                ),
              ),
            if (provider.hasPlaylists) ...[
              SliverToBoxAdapter(
                child: DiscoverSectionHeader(
                  title: '精选歌单',
                  subtitle: '总有一份，适合此刻',
                  onViewAll: () =>
                      Navigator.pushNamed(context, '/recommended/playlists'),
                ),
              ),
              SliverToBoxAdapter(
                  child: DiscoverPlaylistRow(playlists: provider.topPlaylists)),
            ],
            if (provider.hasRanks) ...[
              SliverToBoxAdapter(
                child: DiscoverSectionHeader(
                  title: '热门榜单',
                  onViewAll: () => _showRankList(provider.rankList),
                ),
              ),
              SliverToBoxAdapter(
                  child: DiscoverRankRow(ranks: provider.rankList)),
            ],
            if (provider.hasTopSongs) ...[
              const SliverToBoxAdapter(
                  child: DiscoverSectionHeader(title: '新歌速递')),
              SliverToBoxAdapter(
                  child: DiscoverSongRow(songs: provider.topSongs)),
            ],
            if (provider.hasTopAlbums) ...[
              const SliverToBoxAdapter(
                  child: DiscoverSectionHeader(title: '新碟上架')),
              SliverToBoxAdapter(
                  child: DiscoverAlbumRow(albums: provider.topAlbums)),
            ],
            if (provider.hasScenes) ...[
              const SliverToBoxAdapter(
                  child: DiscoverSectionHeader(
                      title: '音乐陪伴每一刻', subtitle: '选一种心情，进入你的场景')),
              SliverToBoxAdapter(
                  child: DiscoverSceneRow(scenes: provider.sceneCategories)),
            ],
            if (provider.hasIp) ...[
              const SliverToBoxAdapter(
                  child: DiscoverSectionHeader(title: '编辑精选')),
              SliverToBoxAdapter(child: DiscoverIpRow(ipList: provider.ipList)),
            ],
            if (provider.hasFm) ...[
              SliverToBoxAdapter(
                child: DiscoverSectionHeader(
                  title: '电台推荐',
                  onViewAll: () => Navigator.pushNamed(context, '/fm'),
                ),
              ),
              SliverToBoxAdapter(child: DiscoverFmRow(fmList: provider.fmList)),
            ],
            const SliverToBoxAdapter(child: PlayerBottomPadding()),
          ],
        ),
      ),
    );
  }

  void _showRankList(List<RankEntry> ranks) {
    showAppBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.65,
          child: Column(
            children: [
              const AppPageHeader(title: '热门榜单'),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                      AppThemeTokens.of(sheetContext).pagePadding,
                      0,
                      AppThemeTokens.of(sheetContext).pagePadding,
                      24),
                  itemCount: ranks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final rank = ranks[index];
                    return AppSurface(
                      padding: const EdgeInsets.all(12),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Navigator.pushNamed(context, '/rank/detail',
                            arguments: {'id': rank.id, 'name': rank.name});
                      },
                      child: Row(
                        children: [
                          DiscoverArtwork(
                              url: rank.coverUrl,
                              size: 52,
                              icon: Icons.leaderboard_rounded),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              rank.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  Theme.of(sheetContext).textTheme.titleMedium,
                            ),
                          ),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

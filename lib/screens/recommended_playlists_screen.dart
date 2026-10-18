// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/playlist.dart';
import '../services/music_service.dart';
import '../ui/app_ui.dart';
import '../ui/components/cover_art.dart';
import '../ui/components/player_bottom_padding.dart';

class RecommendedPlaylistsScreen extends StatefulWidget {
  const RecommendedPlaylistsScreen({super.key});

  @override
  State<RecommendedPlaylistsScreen> createState() =>
      _RecommendedPlaylistsScreenState();
}

class _RecommendedPlaylistsScreenState
    extends State<RecommendedPlaylistsScreen> {
  late final MusicService _musicService;
  final List<Playlist> _playlists = [];
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _offset = 0;
  int _requestId = 0;
  static const int _limit = 30;

  @override
  void initState() {
    super.initState();
    _musicService = context.read<MusicService>();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    if (_loading || !_hasMore) return;
    final request = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final playlists = await _musicService.getTopPlaylists(
        limit: _limit,
        offset: _offset,
      );
      if (!mounted || request != _requestId) return;
      setState(() {
        _playlists.addAll(playlists);
        _offset += playlists.length;
        _hasMore = playlists.length >= _limit;
      });
    } catch (_) {
      if (mounted && request == _requestId) {
        setState(() => _error = '暂时无法加载歌单，请重试');
      }
    } finally {
      if (mounted && request == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _onRefresh() async {
    _requestId++;
    setState(() {
      _playlists.clear();
      _offset = 0;
      _hasMore = true;
      _loading = false;
      _error = null;
    });
    await _loadPlaylists();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final scale = MediaQuery.textScalerOf(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AppPageBody(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.depth == 0 &&
                    notification is ScrollEndNotification &&
                    notification.metrics.extentAfter < 320 &&
                    _error == null) {
                  _loadPlaylists();
                }
                return false;
              },
              child: LayoutBuilder(builder: (context, constraints) {
                final available = constraints.maxWidth - tokens.pagePadding * 2;
                final columns =
                    available < 260 || (scale.scale(14) > 22 && available < 600)
                        ? 1
                        : (available / 180).floor().clamp(2, 5).toInt();
                final width = (available - (columns - 1) * 16) / columns;
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                        child: AppPageHeader(
                      title: '推荐歌单',
                      subtitle: '把适合此刻的音乐，留在身边',
                      showBack: true,
                    )),
                    if (_playlists.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _loading
                            ? const Center(child: AppLoadingIndicator())
                            : AppEmptyState(
                                icon: _error == null
                                    ? Icons.queue_music_rounded
                                    : Icons.cloud_off_rounded,
                                title: _error == null ? '暂时没有歌单' : '歌单加载失败',
                                message: _error ?? '下拉刷新，看看有没有新的音乐灵感。',
                                action: TextButton(
                                    onPressed: _onRefresh,
                                    child: const Text('重新加载')),
                              ),
                      )
                    else ...[
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                            horizontal: tokens.pagePadding),
                        sliver: SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisExtent: width +
                                scale.scale(16) * 3.2 +
                                scale.scale(12) * 1.35 +
                                28,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _playlists.length,
                          itemBuilder: (_, index) =>
                              _playlistCard(_playlists[index], width),
                        ),
                      ),
                      if (_loading)
                        const SliverToBoxAdapter(
                            child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ))
                      else if (_hasMore)
                        SliverToBoxAdapter(
                            child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(children: [
                            if (_error != null)
                              Text(_error!, textAlign: TextAlign.center),
                            TextButton(
                                onPressed: _loadPlaylists,
                                child: Text(_error == null ? '加载更多歌单' : '重试')),
                          ]),
                        )),
                      const SliverToBoxAdapter(
                          child: PlayerBottomPadding(showLabel: false)),
                    ],
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _playlistCard(Playlist playlist, double width) {
    final theme = Theme.of(context);
    return AppSurface(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.pushNamed(context, '/playlist/detail', arguments: {
        'gcId': playlist.globalCollectionId ??
            'collection_3_${playlist.createUserId}_${playlist.id}_0',
        'name': playlist.name,
      }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoverArt(url: playlist.coverUrl, size: width, borderRadius: 0),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(playlist.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('${playlist.trackCount} 首歌曲',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

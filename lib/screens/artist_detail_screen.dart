// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import '../ui/app_ui.dart';
import '../ui/components/collection_header.dart';
import '../services/api_exception.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../ui/components/song_tile.dart';
import '../ui/components/player_bottom_padding.dart';

class ArtistDetailScreen extends StatefulWidget {
  final int artistId;
  final String? artistName;

  const ArtistDetailScreen(
      {super.key, required this.artistId, this.artistName});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen>
    with SingleTickerProviderStateMixin {
  final _musicService = MusicService();

  late TabController _tabCtrl;

  Map<String, dynamic>? _detail;
  List<Song> _songs = [];
  List<Album> _albums = [];
  // MV: List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _followBusy = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loadFailed = false;
      _isLoading = _songs.isEmpty && _albums.isEmpty && _detail == null;
    });
    try {
      final results = await Future.wait([
        _musicService.getArtistDetail(widget.artistId),
        _musicService.getArtistAudios(widget.artistId, pageSize: 500),
        _musicService.getArtistAlbums(widget.artistId, pageSize: 50),
        // MV: _musicService.getArtistVideos(widget.artistId),
      ]);
      if (mounted) {
        setState(() {
          _detail = results[0] as Map<String, dynamic>?;
          _songs = results[1] as List<Song>;
          _albums = results[2] as List<Album>;
          // MV: _videos = results[3] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e, s) {
      Log.e('artist_detail_screen', 'load error', e, s);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_followBusy) return;
    setState(() => _followBusy = true);
    try {
      if (_isFollowing) {
        await _musicService.unfollowArtist(widget.artistId);
      } else {
        await _musicService.followArtist(widget.artistId);
      }
      if (mounted) setState(() => _isFollowing = !_isFollowing);
    } catch (e, s) {
      Log.e('artist_detail_screen', 'follow error', e, s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('关注操作失败：${friendlyError(e)}')));
      }
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  String? get _avatarUrl {
    final d = _detail;
    if (d == null) return null;
    // 多字段回退
    final raw = d['data'] as Map<String, dynamic>? ?? d;
    var url = raw['sizable_avatar'] as String? ??
        raw['avatar'] as String? ??
        raw['imgurl'] as String? ??
        raw['Avatar'] as String?;
    if (url != null && url.startsWith('//')) url = 'https:$url';
    return url;
  }

  String get _artistName =>
      _detail?['data']?['author_name'] as String? ??
      _detail?['data']?['name'] as String? ??
      _detail?['data']?['singer_name'] as String? ??
      widget.artistName ??
      '歌手';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabHeight =
        (MediaQuery.textScalerOf(context).scale(14) + 28).clamp(52.0, 88.0);
    return Scaffold(
      appBar: AppBar(title: const Text('歌手')),
      body: _isLoading
          ? const Center(child: AppLoadingIndicator())
          : AppPageBody(
              child: RefreshIndicator(
              onRefresh: _load,
              child: NestedScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                headerSliverBuilder: (_, __) => [
                  SliverToBoxAdapter(
                      child: CollectionHeader(
                    title: _artistName,
                    kind: '歌手',
                    coverUrl: _avatarUrl,
                    fallbackIcon: Icons.person_rounded,
                    subtitle: '${_songs.length} 首单曲 · ${_albums.length} 张专辑',
                    actions: [
                      FilledButton.icon(
                        onPressed: _songs.isEmpty
                            ? null
                            : () => context
                                .read<PlayerProvider>()
                                .playSong(_songs.first, playlist: _songs),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('播放全部'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _followBusy ? null : _toggleFollow,
                        icon: Icon(_isFollowing
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded),
                        label: Text(_isFollowing ? '已关注' : '关注'),
                      ),
                    ],
                  )),
                  SliverPersistentHeader(
                      pinned: true,
                      delegate: _ArtistTabs(
                        height: tabHeight,
                        child: TabBar(controller: _tabCtrl, tabs: [
                          Tab(text: '单曲', height: tabHeight),
                          Tab(text: '专辑', height: tabHeight),
                        ]),
                      )),
                ],
                body: TabBarView(controller: _tabCtrl, children: [
                  _buildSongsTab(),
                  _buildAlbumsTab(theme),
                ]),
              ),
            )),
    );
  }

  Widget _buildSongsTab() {
    if (_songs.isEmpty) {
      return AppEmptyState(
        icon: _loadFailed ? Icons.cloud_off_rounded : Icons.music_note_rounded,
        title: _loadFailed ? '歌手内容暂时无法加载' : '暂无单曲',
        action: _loadFailed
            ? FilledButton.tonalIcon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试'))
            : null,
      );
    }
    return ListView.builder(
      key: const PageStorageKey('artist-songs'),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _songs.length + 1,
      itemBuilder: (_, index) => index == _songs.length
          ? const PlayerBottomPadding(showLabel: false)
          : SongTile(
              song: _songs[index],
              onTap: (song) => context
                  .read<PlayerProvider>()
                  .playSong(song, playlist: _songs)),
    );
  }

  Widget _buildAlbumsTab(ThemeData theme) {
    if (_albums.isEmpty) {
      return const AppEmptyState(icon: Icons.album_rounded, title: '暂无专辑');
    }
    final tokens = AppThemeTokens.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final columns = ((constraints.maxWidth - tokens.pagePadding * 2) / 170)
          .floor()
          .clamp(1, 5);
      final tileWidth =
          (constraints.maxWidth - tokens.pagePadding * 2 - (columns - 1) * 16) /
              columns;
      final textScaler = MediaQuery.textScalerOf(context);
      final tileHeight = tileWidth +
          textScaler.scale(14) * 2.8 +
          textScaler.scale(12) * 1.4 +
          20;
      return GridView.builder(
        key: const PageStorageKey('artist-albums'),
        padding: EdgeInsets.fromLTRB(tokens.pagePadding, 20, tokens.pagePadding,
            AppChrome.miniPlayerExtent(context) + 32),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 20,
          crossAxisSpacing: 16,
          mainAxisExtent: tileHeight,
        ),
        itemCount: _albums.length,
        itemBuilder: (context, index) {
          final album = _albums[index];
          return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(tokens.cardRadius),
                onTap: album.id <= 0
                    ? null
                    : () => Navigator.pushNamed(context, '/album/detail',
                        arguments: {'id': album.id, 'name': album.name}),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(tokens.cardRadius),
                            child: album.coverUrl?.isNotEmpty == true
                                ? CachedNetworkImage(
                                    imageUrl: album.coverUrl!
                                        .replaceAll('{size}', '480'),
                                    memCacheWidth: 480,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        _albumPlaceholder(theme),
                                  )
                                : _albumPlaceholder(theme),
                          )),
                      const SizedBox(height: 10),
                      Text(album.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall),
                      if (album.songCount != null && album.songCount! > 0) ...[
                        const SizedBox(height: 4),
                        Text('${album.songCount} 首',
                            style: theme.textTheme.bodySmall),
                      ],
                    ]),
              ));
        },
      );
    });
  }

  Widget _albumPlaceholder(ThemeData theme) => ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Icon(Icons.album_rounded,
            size: 40, color: theme.colorScheme.onSurfaceVariant),
      );

  // ─── MV Tab ───

  // MV: Widget _buildVideosTab(ColorScheme cs, TextTheme tt) {
  // MV:   if (_videos.isEmpty) {
  // MV:     return const Center(child: Text('暂无 MV'));
  // MV:   }
  // MV:   return GridView.builder(
  // MV:     padding: const EdgeInsets.all(12),
  // MV:     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
  // MV:       crossAxisCount: 2,
  // MV:       mainAxisSpacing: 12,
  // MV:       crossAxisSpacing: 12,
  // MV:       childAspectRatio: 0.75,
  // MV:     ),
  // MV:     itemCount: _videos.length,
  // MV:     itemBuilder: (_, i) {
  // MV:       final mv = _videos[i];
  // MV:       final name = mv['MvName'] as String? ??
  // MV:           mv['name'] as String? ??
  // MV:           mv['mvname'] as String? ?? '';
  // MV:       final img = mv['Pic'] as String? ??
  // MV:           mv['imgurl'] as String? ??
  // MV:           mv['img'] as String? ?? '';
  // MV:       final hash = mv['MvHash'] as String? ?? mv['hash'] as String?;
  // MV:       return GestureDetector(
  // MV:         onTap: () {
  // MV:           if (hash != null) {
  // MV:             Navigator.pushNamed(context, '/mv',
  // MV:                 arguments: {'hash': hash, 'name': name});
  // MV:           }
  // MV:         },
  // MV:         child: Column(
  // MV:           crossAxisAlignment: CrossAxisAlignment.start,
  // MV:           children: [
  // MV:             Expanded(
  // MV:               child: ClipRRect(
  // MV:                 borderRadius: AppShape.sm,
  // MV:                 child: Stack(
  // MV:                   fit: StackFit.expand,
  // MV:                   children: [
  // MV:                     if (img.isNotEmpty)
  // MV:                       CachedNetworkImage(
  // MV:                         imageUrl: img.replaceAll('{size}', '240'),
  // MV:                         fit: BoxFit.cover,
  // MV:                         errorWidget: (_, __, ___) => Container(
  // MV:                           color: cs.surfaceContainerHighest,
  // MV:                           child: const Icon(Icons.video_library),
  // MV:                         ),
  // MV:                       )
  // MV:                     else
  // MV:                       Container(
  // MV:                         color: cs.surfaceContainerHighest,
  // MV:                         child: const Icon(Icons.video_library),
  // MV:                       ),
  // MV:                     const Center(
  // MV:                       child: Icon(Icons.play_circle_fill,
  // MV:                           color: Colors.white70, size: 40),
  // MV:                     ),
  // MV:                   ],
  // MV:                 ),
  // MV:               ),
  // MV:             ),
  // MV:             const SizedBox(height: 6),
  // MV:             Text(name,
  // MV:                 maxLines: 2,
  // MV:                 overflow: TextOverflow.ellipsis,
  // MV:                 style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
  // MV:           ],
  // MV:         ),
  // MV:       );
  // MV:     },
  // MV:   );
  // MV: }
}

class _ArtistTabs extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  const _ArtistTabs({required this.height, required this.child});
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: Theme.of(context).colorScheme.surface, child: child);
  @override
  bool shouldRebuild(covariant _ArtistTabs oldDelegate) =>
      height != oldDelegate.height || child != oldDelegate.child;
}

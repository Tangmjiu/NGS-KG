import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/playlist_tag.dart';
import '../models/radio.dart';
import '../models/playlist.dart';
import '../models/rank_entry.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../models/scene_category.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../providers/player_provider.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final MusicService _musicService = MusicService();
  List<PlaylistTag> _tags = [];
  List<RadioStation> _fmList = [];
  List<Playlist> _topPlaylists = [];
  List<RankEntry> _rankList = [];
  List<Map<String, dynamic>> _banners = [];
  List<Song> _topSongs = [];
  List<Album> _topAlbums = [];
  List<SceneCategory> _sceneCategories = [];
  List<Map<String, dynamic>> _ipList = [];
  List<Map<String, dynamic>> _styleTags = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadTags(),
      _loadFm(),
      _loadPlaylists(),
      _loadRanks(),
      _loadBanners(),
      _loadTopSongs(),
      _loadTopAlbums(),
      _loadSceneCategories(),
      _loadIp(),
      _loadStyleTags(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadTags() async {
    try {
      final tags = await _musicService.getPlaylistTags();
      if (mounted) setState(() => _tags = tags);
    } catch (e, s) { Log.e('discover_screen', 'error', e, s); }
  }

  Future<void> _loadFm() async {
    try {
      final fm = await _musicService.getFmRecommend();
      if (mounted) setState(() => _fmList = fm.take(6).toList());
    } catch (e, s) { Log.e('discover_screen', 'error', e, s); }
  }

  Future<void> _loadPlaylists() async {
    try {
      final list = await _musicService.getTopPlaylists(limit: 10);
      if (mounted) setState(() => _topPlaylists = list);
    } catch (e, s) { Log.e('discover_screen', 'error', e, s); }
  }

  Future<void> _loadRanks() async {
    try {
      final ranks = await _musicService.getRankList();
      if (mounted) setState(() => _rankList = ranks.take(4).toList());
    } catch (e, s) { Log.e('discover_screen', 'error', e, s); }
  }

  Future<void> _loadBanners() async {
    try {
      final banners = await _musicService.getYuekuBanner();
      if (mounted) setState(() => _banners = banners);
    } catch (e, s) { Log.e('discover_screen', 'error', e, s); }
  }

  Future<void> _loadTopSongs() async {
    try {
      final songs = await _musicService.getTopSongs();
      if (mounted) setState(() => _topSongs = songs.take(10).toList());
    } catch (e, s) { Log.e('discover_screen', 'error', e, s); }
  }

  Future<void> _loadTopAlbums() async {
    try {
      final albums = await _musicService.getTopAlbums(pageSize: 10);
      if (mounted) setState(() => _topAlbums = albums);
    } catch (e, s) { Log.e('discover_screen', 'error', e, s); }
  }

  Future<void> _loadSceneCategories() async {
    try {
      final scenes = await _musicService.getSceneLists();
      if (mounted) setState(() => _sceneCategories = scenes.take(8).toList());
    } catch (e, s) { Log.e('discover_screen', 'error', e, s); }
  }

  Future<void> _loadIp() async {
    try {
      final ip = await _musicService.getTopIp();
      if (mounted) setState(() => _ipList = ip.take(6).toList());
    } catch (e, s) { Log.e('discover_screen', 'error', e, s); }
  }

  Future<void> _loadStyleTags() async {
    try {
      final tags = await _musicService.getStyleTags();
      if (mounted) setState(() => _styleTags = tags);
    } catch (e, s) { Log.e('discover_screen', 'error', e, s); }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: CustomScrollView(
        slivers: [
          // ── Title ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 4),
              child: Text('发现', style: tt.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(
              child: SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
            )
          else ...[
            // ── Banner ──
            if (_banners.isNotEmpty)
              SliverToBoxAdapter(child: _buildBanner(cs)),
            // ── Quick actions ──
            SliverToBoxAdapter(child: _buildQuickActions(cs, tt)),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            // ── Top playlists ──
            if (_topPlaylists.isNotEmpty) ...[
              _buildSectionHeader('推荐歌单', tt, onViewAll: () {
                Navigator.pushNamed(context, '/category/selection');
              }),
              SliverToBoxAdapter(child: _buildPlaylistRow(cs)),
            ],
            // ── Hot ranks ──
            if (_rankList.isNotEmpty) ...[
              _buildSectionHeader('热门榜单', tt, onViewAll: () {
                _showRankList();
              }),
              SliverToBoxAdapter(child: _buildRankRow(cs)),
            ],
            // ── New songs ──
            if (_topSongs.isNotEmpty) ...[
              _buildSectionHeader('新歌速递', tt),
              SliverToBoxAdapter(child: _buildTopSongsRow(cs)),
            ],
            // ── New albums ──
            if (_topAlbums.isNotEmpty) ...[
              _buildSectionHeader('新碟上架', tt),
              SliverToBoxAdapter(child: _buildTopAlbumsRow(cs)),
            ],
            // ── Scene music ──
            if (_sceneCategories.isNotEmpty) ...[
              _buildSectionHeader('场景音乐', tt),
              SliverToBoxAdapter(child: _buildSceneRow(cs, tt)),
            ],
            // ── Editor's picks ──
            if (_ipList.isNotEmpty) ...[
              _buildSectionHeader('编辑精选', tt),
              SliverToBoxAdapter(child: _buildIpRow(cs)),
            ],
            // ── Radio stations ──
            if (_fmList.isNotEmpty) ...[
              _buildSectionHeader('电台推荐', tt, onViewAll: () {
                Navigator.pushNamed(context, '/fm');
              }),
              SliverToBoxAdapter(child: _buildFmRow(cs)),
            ],
            // ── All categories ──
            if (_styleTags.isNotEmpty || _tags.isNotEmpty) ...[
              _buildSectionHeader('全部分类', tt, onViewAll: () {
                Navigator.pushNamed(context, '/category/selection');
              }),
              SliverToBoxAdapter(child: _buildCategoryGrid(cs, tt)),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ],
      ),
    );
  }

  // ────────────── Banner ──────────────

  Widget _buildBanner(ColorScheme cs) {
    return SizedBox(
      height: 160,
      child: PageView.builder(
        padEnds: true,
        pageSnapping: true,
        itemCount: _banners.length,
        itemBuilder: (_, i) {
          final banner = _banners[i];
          final imgUrl = (banner['banner'] as String? ?? banner['img'] as String? ?? '')
              .replaceAll('{size}', '720');
          final title = banner['title'] as String? ?? banner['name'] as String? ?? '';
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: cs.surfaceContainerHighest,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: imgUrl.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(imageUrl: imgUrl, fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: cs.surfaceContainerHighest),
                          errorWidget: (_, __, ___) => Container(color: cs.surfaceContainerHighest, child: const Icon(Icons.broken_image)),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.center,
                              colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          child: Text(title,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    )
                  : Center(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            ),
          );
        },
      ),
    );
  }

  // ────────────── Quick actions ──────────────

  static const _actionGradients = [
    [Color(0xFFFF6B35), Color(0xFFF7C948)],  // 排行榜 → 橙金
    [Color(0xFF7C4DFF), Color(0xFF448AFF)],  // 电台 → 紫蓝
    [Color(0xFF00BFA5), Color(0xFF69F0AE)],  // 每日推荐 → 青绿
    [Color(0xFFFF4081), Color(0xFFFF6E40)],  // 新歌首发 → 粉橙
  ];

  Widget _buildQuickActions(ColorScheme cs, TextTheme tt) {
    final player = context.read<PlayerProvider>();
    final actions = [
      _ActionItem(Icons.emoji_events, '排行榜', () {
        if (_rankList.isNotEmpty) {
          Navigator.pushNamed(context, '/rank/detail',
              arguments: {'id': _rankList.first.id, 'name': _rankList.first.name});
        }
      }),
      _ActionItem(Icons.radio, '电台', () => Navigator.pushNamed(context, '/fm')),
      _ActionItem(Icons.auto_awesome, '每日推荐', () async {
        try {
          final card = await _musicService.getCardSongs(1);
          if (card.songs.isNotEmpty && mounted) {
            player.playSong(card.songs.first, playlist: card.songs);
            Navigator.pushNamed(context, '/player');
          }
        } catch (e, s) { Log.e('discover_screen', 'error', e, s); }
      }),
      _ActionItem(Icons.music_note, '新歌首发', () async {
        try {
          final songs = await _musicService.getTopSongs();
          if (songs.isNotEmpty && mounted) {
            player.playSong(songs.first, playlist: songs);
            Navigator.pushNamed(context, '/player');
          }
        } catch (e, s) { Log.e('discover_screen', 'error', e, s); }
      }),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (int i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              _buildGradientCard(i, actions[i], cs, tt),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGradientCard(int index, _ActionItem item, ColorScheme cs, TextTheme tt) {
    final colors = _actionGradients[index];
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(item.icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(item.label,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  // ────────────── Section header ──────────────

  SliverToBoxAdapter _buildSectionHeader(String title, TextTheme tt, {VoidCallback? onViewAll}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Row(
          children: [
            Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            GestureDetector(
              onTap: onViewAll,
              child: Text('查看更多', style: tt.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────── Top playlists row ──────────────

  Widget _buildPlaylistRow(ColorScheme cs) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _topPlaylists.length,
        itemBuilder: (_, i) {
          final pl = _topPlaylists[i];
          return GestureDetector(
            onTap: () {
              if (pl.globalCollectionId != null) {
                Navigator.pushNamed(context, '/playlist/detail',
                    arguments: {'gcId': pl.globalCollectionId, 'name': pl.name});
              } else {
                Navigator.pushNamed(context, '/playlist/detail',
                    arguments: {'gcId': pl.id.toString(), 'name': pl.name});
              }
            },
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: pl.coverUrl != null
                        ? CachedNetworkImage(imageUrl: pl.coverUrl!, width: 140, height: 140, fit: BoxFit.cover)
                        : Container(width: 140, height: 140, color: cs.surfaceContainerHighest, child: Icon(Icons.playlist_play, color: cs.onSurfaceVariant)),
                  ),
                  const SizedBox(height: 6),
                  Text(pl.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ────────────── Rank row ──────────────

  Widget _buildRankRow(ColorScheme cs) {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _rankList.length,
        itemBuilder: (_, i) {
          final rank = _rankList[i];
          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/rank/detail', arguments: {'id': rank.id, 'name': rank.name}),
            child: Container(
              width: 110,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: rank.coverUrl != null
                        ? CachedNetworkImage(imageUrl: rank.coverUrl!, width: 100, height: 100, fit: BoxFit.cover)
                        : Container(width: 100, height: 100, color: cs.surfaceContainerHighest, child: Icon(Icons.leaderboard, color: cs.onSurfaceVariant)),
                  ),
                  const SizedBox(height: 4),
                  Text(rank.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ────────────── Top songs row ──────────────

  void _playSongsFrom(int i) {
    final player = context.read<PlayerProvider>();
    player.playSong(_topSongs[i], playlist: _topSongs.sublist(i));
    Navigator.pushNamed(context, '/player');
  }

  Widget _buildTopSongsRow(ColorScheme cs) {
    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _topSongs.length,
        itemBuilder: (_, i) {
          final song = _topSongs[i];
          return GestureDetector(
            onTap: () => _playSongsFrom(i),
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: song.albumCoverUrl != null
                             ? CachedNetworkImage(
                                 imageUrl: song.albumCoverUrl!, width: 120, height: 120, fit: BoxFit.cover,
                                 placeholder: (_, __) => Container(width: 120, height: 120, color: cs.surfaceContainerHighest),
                                 errorWidget: (_, __, ___) => Container(width: 120, height: 120, color: cs.surfaceContainerHighest, child: Icon(Icons.music_note, color: cs.onSurfaceVariant)),
                               )
                             : Container(width: 120, height: 120,
                                 color: cs.surfaceContainerHighest,
                                 child: Icon(Icons.music_note, color: cs.onSurfaceVariant)),
                   ),
                   const SizedBox(height: 6),
                   Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                       style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                   const SizedBox(height: 2),
                   Text(song.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis,
                       style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                 ],
               ),
             ),
           );
         },
       ),
     );
   }

  // ────────────── Top albums row ──────────────

  Widget _buildTopAlbumsRow(ColorScheme cs) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _topAlbums.length,
        itemBuilder: (_, i) {
          final album = _topAlbums[i];
          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/album/detail',
                arguments: {'id': album.id, 'name': album.name}),
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: album.coverUrl != null
                             ? CachedNetworkImage(
                                 imageUrl: album.coverUrl!, width: 140, height: 140, fit: BoxFit.cover,
                                 placeholder: (_, __) => Container(width: 140, height: 140, color: cs.surfaceContainerHighest),
                                 errorWidget: (_, __, ___) => Container(width: 140, height: 140, color: cs.surfaceContainerHighest, child: Icon(Icons.album, color: cs.onSurfaceVariant)),
                               )
                             : Container(width: 140, height: 140,
                                 color: cs.surfaceContainerHighest,
                                 child: Icon(Icons.album, color: cs.onSurfaceVariant)),
                  ),
                  const SizedBox(height: 6),
                  Text(album.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 2),
                  if (album.artistName != null)
                    Text(album.artistName!, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ────────────── Scene category row ──────────────

  Widget _buildSceneRow(ColorScheme cs, TextTheme tt) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _sceneCategories.length,
        itemBuilder: (_, i) {
          final scene = _sceneCategories[i];
          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/fm'),
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: scene.iconUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                                child: CachedNetworkImage(
                                    imageUrl: scene.iconUrl!, width: 64, height: 64, fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(width: 64, height: 64, color: cs.primaryContainer.withValues(alpha: 0.4)),
                                    errorWidget: (_, __, ___) => Icon(Icons.explore, color: cs.primary, size: 28),
                                  ),
                          )
                        : Icon(Icons.explore, color: cs.primary, size: 28),
                  ),
                  const SizedBox(height: 6),
                  Text(scene.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: cs.onSurface)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ────────────── Editor's picks row ──────────────

  Widget _buildIpRow(ColorScheme cs) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _ipList.length,
        itemBuilder: (_, i) {
          final ip = _ipList[i];
          final imgUrl = (ip['img'] as String? ?? ip['sizable_cover'] as String? ?? '')
              .replaceAll('{size}', '480');
          final name = ip['ip_name'] as String? ?? ip['name'] as String? ?? '';
          return Container(
            width: 260,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: imgUrl.isNotEmpty
                       ? CachedNetworkImage(imageUrl: imgUrl, width: 260, height: 112, fit: BoxFit.cover,
                           placeholder: (_, __) => Container(width: 260, height: 112, color: cs.surfaceContainerHighest),
                           errorWidget: (_, __, ___) => Container(width: 260, height: 112, color: cs.surfaceContainerHighest, child: Center(child: Text(name, style: TextStyle(color: cs.onSurfaceVariant)))),
                         )
                       : Container(width: 260, height: 112,
                           color: cs.surfaceContainerHighest,
                           child: Center(child: Text(name, style: TextStyle(color: cs.onSurfaceVariant)))),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ────────────── FM/Radio row ──────────────

  Widget _buildFmRow(ColorScheme cs) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _fmList.length,
        itemBuilder: (_, i) {
          final fm = _fmList[i];
          final img = (fm.coverUrl ?? '').replaceAll('{size}', '240');
          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/fm', arguments: {'fmid': fm.id, 'name': fm.name}),
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: img.isNotEmpty
                        ? CachedNetworkImage(imageUrl: img, width: 64, height: 64, fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(width: 64, height: 64, color: cs.surfaceContainerHighest, child: const Icon(Icons.radio)),
                          )
                        : Container(width: 64, height: 64, color: cs.surfaceContainerHighest, child: const Icon(Icons.radio)),
                  ),
                  const SizedBox(height: 4),
                  Text(fm.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ────────────── Category grid ──────────────

  static const _categoryIcons = {
    '华语': Icons.language,
    '欧美': Icons.public,
    '日语': Icons.flag,
    '韩语': Icons.flag_outlined,
    '流行': Icons.trending_up,
    '摇滚': Icons.flash_on,
    '民谣': Icons.self_improvement,
    '电子': Icons.track_changes,
    '说唱': Icons.mic,
    '轻音乐': Icons.piano,
    '爵士': Icons.music_note,
    '古风': Icons.history_edu,
    'R&B': Icons.headphones,
    '舞曲': Icons.nightlife,
    '古典': Icons.theater_comedy,
    '儿童': Icons.child_care,
    '校园': Icons.school,
    '纯音乐': Icons.queue_music,
  };

  static const _categoryColors = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFF00ACC1),
    Color(0xFFD81B60),
    Color(0xFF3949AB),
  ];

  Widget _buildCategoryGrid(ColorScheme cs, TextTheme tt) {
    final cats = _styleTags.isNotEmpty
        ? _styleTags.map((e) => (e['tagname'] ?? e['name'] ?? '') as String).toList()
        : _tags.map((e) => e.name).toList();
    if (cats.isEmpty) return const SizedBox.shrink();

    final displayCats = cats.length > 16 ? cats.take(16).toList() : cats;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = (screenWidth / 100).floor().clamp(3, 4);
    final itemWidth = (screenWidth - 32 - 12 * (crossAxisCount - 1)) / crossAxisCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: displayCats.asMap().entries.map((entry) {
          final i = entry.key;
          final name = entry.value;
          final icon = _categoryIcons[name] ?? Icons.music_note;
          final color = _categoryColors[i % _categoryColors.length];
          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/category/selection'),
            child: Container(
              width: itemWidth,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 26, color: color),
                  const SizedBox(height: 6),
                  Text(name, style: tt.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w500),
                      maxLines: 1, textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showRankList() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('热门榜单',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const Divider(height: 1),
            SizedBox(
              height: 400,
              child: ListView.builder(
                itemCount: _rankList.length,
                itemBuilder: (_, i) {
                  final r = _rankList[i];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: r.coverUrl != null
                          ? CachedNetworkImage(imageUrl: r.coverUrl!, width: 48, height: 48, fit: BoxFit.cover,
                              placeholder: (_, __) => Container(width: 48, height: 48, color: Theme.of(context).colorScheme.surfaceContainerHighest),
                              errorWidget: (_, __, ___) => Container(width: 48, height: 48, color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.music_note)),
                            )
                          : Container(width: 48, height: 48, color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.music_note)),
                    ),
                    title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/rank/detail', arguments: {'id': r.id, 'name': r.name});
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ActionItem(this.icon, this.label, this.onTap);
}

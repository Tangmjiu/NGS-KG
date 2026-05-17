import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist_tag.dart';
import '../models/radio.dart';
import '../models/playlist.dart';
import '../models/rank_entry.dart';
import '../services/music_service.dart';
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
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadTags() async {
    try {
      final tags = await _musicService.getPlaylistTags();
      if (mounted) setState(() => _tags = tags);
    } catch (_) {}
  }

  Future<void> _loadFm() async {
    try {
      final fm = await _musicService.getFmRecommend();
      if (mounted) setState(() => _fmList = fm.take(6).toList());
    } catch (_) {}
  }

  Future<void> _loadPlaylists() async {
    try {
      final list = await _musicService.getTopPlaylists(limit: 10);
      if (mounted) setState(() => _topPlaylists = list);
    } catch (_) {}
  }

  Future<void> _loadRanks() async {
    try {
      final ranks = await _musicService.getRankList();
      if (mounted) setState(() => _rankList = ranks.take(4).toList());
    } catch (_) {}
  }

  Future<void> _loadBanners() async {
    try {
      final banners = await _musicService.getYuekuBanner();
      if (mounted) setState(() => _banners = banners);
    } catch (_) {}
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
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
              _buildSectionHeader('推荐歌单', tt),
              SliverToBoxAdapter(child: _buildPlaylistRow(cs)),
            ],
            // ── Hot ranks ──
            if (_rankList.isNotEmpty) ...[
              _buildSectionHeader('热门榜单', tt),
              SliverToBoxAdapter(child: _buildRankRow(cs)),
            ],
            // ── Radio stations ──
            if (_fmList.isNotEmpty) ...[
              _buildSectionHeader('电台推荐', tt),
              SliverToBoxAdapter(child: _buildFmRow(cs)),
            ],
            // ── All categories ──
            if (_tags.isNotEmpty) ...[
              _buildSectionHeader('全部分类', tt),
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
              image: imgUrl.isNotEmpty
                  ? DecorationImage(image: NetworkImage(imgUrl), fit: BoxFit.cover)
                  : null,
              color: cs.surfaceContainerHighest,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                ),
              ),
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(16),
              child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }

  // ────────────── Quick actions ──────────────

  Widget _buildQuickActions(ColorScheme cs, TextTheme tt) {
    final player = context.read<PlayerProvider>();
    final actions = [
      _ActionItem(Icons.emoji_events_outlined, '排行榜', () {
        if (_rankList.isNotEmpty) {
          Navigator.pushNamed(context, '/rank/detail',
              arguments: {'id': _rankList.first.id, 'name': _rankList.first.name});
        }
      }),
      _ActionItem(Icons.radio_outlined, '电台', () => Navigator.pushNamed(context, '/fm')),
      _ActionItem(Icons.auto_awesome_outlined, '每日推荐', () async {
        try {
          final card = await _musicService.getCardSongs(1);
          if (card.songs.isNotEmpty && mounted) {
            player.playSong(card.songs.first, playlist: card.songs);
            Navigator.pushNamed(context, '/player');
          }
        } catch (_) {}
      }),
      _ActionItem(Icons.music_note_outlined, '新歌首发', () async {
        try {
          final songs = await _musicService.getTopSongs();
          if (songs.isNotEmpty && mounted) {
            player.playSong(songs.first, playlist: songs);
            Navigator.pushNamed(context, '/player');
          }
        } catch (_) {}
      }),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: actions.map((a) => _buildActionChip(a, cs, tt)).toList(),
      ),
    );
  }

  Widget _buildActionChip(_ActionItem item, ColorScheme cs, TextTheme tt) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(item.icon, color: cs.primary, size: 24),
            ),
            const SizedBox(height: 6),
            Text(item.label, style: tt.labelSmall, textAlign: TextAlign.center, maxLines: 1),
          ],
        ),
      ),
    );
  }

  // ────────────── Section header ──────────────

  SliverToBoxAdapter _buildSectionHeader(String title, TextTheme tt) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Row(
          children: [
            Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('查看更多', style: tt.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                    arguments: {'id': pl.id, 'name': pl.name});
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
                        ? Image.network(pl.coverUrl!, width: 140, height: 140, fit: BoxFit.cover)
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
                        ? Image.network(rank.coverUrl!, width: 100, height: 100, fit: BoxFit.cover)
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
                        ? Image.network(img, width: 64, height: 64, fit: BoxFit.cover)
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

  Widget _buildCategoryGrid(ColorScheme cs, TextTheme tt) {
    final icons = [
      Icons.music_note, Icons.history_edu, Icons.flash_on, Icons.self_improvement,
      Icons.track_changes, Icons.mic, Icons.piano, Icons.headphones,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: _tags.take(8).toList().asMap().entries.map((entry) {
          final i = entry.key;
          final tag = entry.value;
          final name = tag.name;
          final tagId = tag.id;
          final son = tag.children ?? [];
          return GestureDetector(
            onTap: () {
              if (son.isNotEmpty && son.first.id > 0) {
                Navigator.pushNamed(context, '/playlist/category',
                    arguments: {'id': son.first.id, 'name': son.first.name});
              } else if (tagId > 0) {
                Navigator.pushNamed(context, '/playlist/category',
                    arguments: {'id': tagId, 'name': name});
              }
            },
            child: Container(
              width: (MediaQuery.of(context).size.width - 16 * 2 - 12 * 3) / 4,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(icons[i % icons.length], size: 24, color: cs.primary),
                  const SizedBox(height: 6),
                  Text(name, style: tt.labelSmall, maxLines: 1, textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }).toList(),
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

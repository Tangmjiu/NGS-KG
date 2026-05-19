import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import '../models/song.dart';
import '../models/latest_listen_info.dart';
import '../services/music_service.dart';
import '../models/song_mapper.dart';
import '../widgets/song_tile.dart';
import 'discover_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  final MusicService _musicService = MusicService();
  List<Song> _recommended = [];
  LatestListenInfo? _latestListen;
  bool _showContinueBanner = false;
  final Map<int, List<Song>> _cardSongs = {};
  final Map<int, String> _cardNames = {};

  Widget _buildSongList(List<Song> songs, String title) {
    if (songs.isEmpty) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    final displaySongs = songs.take(5).toList();
    final player = context.read<PlayerProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (songs.length > 5)
                GestureDetector(
                  onTap: () {
                    player.playSong(displaySongs.first, playlist: songs);
                    Navigator.pushNamed(context, '/player');
                  },
                  child: Text('查看更多', style: tt.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
            ],
          ),
        ),
        Column(
          children: displaySongs.map((song) => SongTile(
            song: song,
            onTap: (s) => player.playSong(s, playlist: songs),
          )).toList(),
        ),
      ],
    );
  }

  static const _cardTitles = {
    1: '私人专属好歌',
    2: '经典怀旧金曲',
    3: '热门好歌精选',
    4: '小众宝藏佳作',
    5: '潮流尝鲜',
    6: 'VIP专属推荐',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaylistProvider>().fetchTopPlaylists();
      _loadRecommended();
      _loadCardSongs();
      _checkLatestListen();
    });
  }

  Future<void> _loadRecommended() async {
    try {
      final songs = await _musicService.getTopSongs();
      if (mounted) setState(() => _recommended = songs.take(10).toList());
    } catch (_) {}
  }

  Future<void> _loadCardSongs() async {
    for (int id = 1; id <= 6; id++) {
      try {
        final data = await _musicService.getCardSongs(id);
        if (mounted) {
          _cardNames[id] = data.recDesc.isNotEmpty ? data.recDesc : _cardTitles[id] ?? '';
          _cardSongs[id] = data.songs;
        }
      } catch (_) {}
    }
  }

  Future<void> _checkLatestListen() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    try {
      final latest = await _musicService.getLatestListen();
      if (latest != null && latest.info != null && mounted) {
        setState(() {
          _latestListen = latest;
          _showContinueBanner = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _continueListen() async {
    if (_latestListen == null || _latestListen!.info == null) return;
    final song = SongMapper.fromTrackJson(_latestListen!.info!);
    if (song == null) return;
    final position = Duration(seconds: _latestListen!.position);
    final player = context.read<PlayerProvider>();
    await player.playSong(song);
    if (position.inSeconds > 0) {
      await player.seek(position);
    }
    setState(() => _showContinueBanner = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildHome(),
          const DiscoverScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (i) => setState(() => _currentTab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首页'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: '发现'),
          NavigationDestination(icon: Icon(Icons.person_outlined), selectedIcon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }

  Widget _buildHome() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Consumer<PlaylistProvider>(
      builder: (_, provider, __) {
        return RefreshIndicator(
          onRefresh: () async {
            await provider.fetchTopPlaylists();
            await _loadRecommended();
          },
          child: CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _SearchHeaderDelegate(
                  child: Container(
                    color: cs.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => Navigator.pushNamed(context, '/search'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.search, size: 20, color: cs.onSurfaceVariant),
                                    const SizedBox(width: 8),
                                    Text('搜索歌曲、歌手、歌单',
                                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Consumer<AuthProvider>(
                          builder: (_, auth, __) => IconButton(
                            icon: Icon(auth.isLoggedIn ? Icons.person : Icons.person_outline,
                                color: cs.onSurfaceVariant),
                            onPressed: () {
                              if (!auth.isLoggedIn) Navigator.pushNamed(context, '/login');
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    if (_showContinueBanner && _latestListen != null)
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.play_circle_outline),
                          title: Text(
                            _latestListen!.info?['name'] ?? '继续播放',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: const Text('点击继续播放'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.play_arrow),
                                tooltip: '继续播放',
                                onPressed: _continueListen,
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                tooltip: '关闭',
                                onPressed: () => setState(() => _showContinueBanner = false),
                              ),
                            ],
                          ),
                          onTap: _continueListen,
                        ),
                      ),
                    if (provider.topPlaylists.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('推荐歌单', style: tt.headlineSmall),
                            TextButton(
                              onPressed: () => Navigator.pushNamed(context, '/category/selection'),
                              child: const Text('更多'),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: provider.topPlaylists.length,
                          itemBuilder: (_, i) {
                            final pl = provider.topPlaylists[i];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(context, '/playlist/detail', arguments: {
                                    'gcId': pl.globalCollectionId ?? pl.id.toString(),
                                    'name': pl.name,
                                  });
                                },
                                child: SizedBox(
                                width: 130,
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: pl.coverUrl != null
                                            ? CachedNetworkImage(
                                                imageUrl: pl.coverUrl!, width: 130, height: 130,
                                                fit: BoxFit.cover,
                                                placeholder: (_, __) => Container(color: cs.surfaceContainerHighest, width: 130, height: 130),
                                                errorWidget: (_, __, ___) => Container(color: cs.surfaceContainerHighest, width: 130, height: 130, child: const Icon(Icons.playlist_play)),
                                              )
                                            : Container(color: cs.surfaceContainerHighest, width: 130, height: 130, child: const Icon(Icons.playlist_play)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(pl.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.bodySmall),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    if (_recommended.isNotEmpty)
                      _buildSongList(_recommended, '新歌推荐'),
                    if (_cardSongs[1]?.isNotEmpty ?? false)
                      _buildSongList(_cardSongs[1]!, _cardNames[1] ?? '私人专属好歌'),
                    if (_cardSongs[2]?.isNotEmpty ?? false)
                      _buildSongList(_cardSongs[2]!, _cardNames[2] ?? '经典怀旧金曲'),
                    if (_cardSongs[3]?.isNotEmpty ?? false)
                      _buildSongList(_cardSongs[3]!, _cardNames[3] ?? '热门好歌精选'),
                    if (_cardSongs[4]?.isNotEmpty ?? false)
                      _buildSongList(_cardSongs[4]!, _cardNames[4] ?? '小众宝藏佳作'),
                    if (_cardSongs[5]?.isNotEmpty ?? false)
                      _buildSongList(_cardSongs[5]!, _cardNames[5] ?? '潮流尝鲜'),
                    if (_cardSongs[6]?.isNotEmpty ?? false)
                      _buildSongList(_cardSongs[6]!, _cardNames[6] ?? 'VIP专属推荐'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  const _SearchHeaderDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => 56;

  @override
  double get minExtent => 56;

  @override
  bool shouldRebuild(covariant _SearchHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

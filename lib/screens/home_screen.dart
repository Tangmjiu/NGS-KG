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
import '../utils/logger.dart';
import 'discover_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

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

  Widget _buildSongList(List<Song> songs, String title, {Future<List<Song>> Function()? onEnd}) {
    if (songs.isEmpty) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final player = context.read<PlayerProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        ),
        SizedBox(
          height: 170,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: songs.length,
            itemBuilder: (_, i) {
              final song = songs[i];
              return GestureDetector(
                onTap: () {
                  player.playlistEndProvider = onEnd;
                  player.playSong(song, playlist: songs.sublist(i));
                },
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: song.albumCoverUrl != null
                            ? CachedNetworkImage(imageUrl: song.albumCoverUrl!, width: 120, height: 120, fit: BoxFit.cover,
                                placeholder: (_, __) => Container(width: 120, height: 120, color: cs.surfaceContainerHighest),
                                errorWidget: (_, __, ___) => Container(width: 120, height: 120, color: cs.surfaceContainerHighest, child: const Icon(Icons.music_note)),
                              )
                            : Container(width: 120, height: 120, color: cs.surfaceContainerHighest, child: const Icon(Icons.music_note)),
                      ),
                      const SizedBox(height: 4),
                      Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                      Text(song.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              );
            },
          ),
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
    } catch (e, s) { Log.e('home_screen', 'error', e, s); }
  }

  Future<void> _loadCardSongs() async {
    for (int id = 1; id <= 6; id++) {
      try {
        final data = await _musicService.getCardSongs(id);
        if (mounted) {
          _cardNames[id] = data.recDesc.isNotEmpty ? data.recDesc : _cardTitles[id] ?? '';
          _cardSongs[id] = data.songs;
        }
      } catch (e, s) { Log.e('home_screen', 'error', e, s); }
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
    } catch (e, s) { Log.e('home_screen', 'error', e, s); }
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
    final topSafe = MediaQuery.of(context).padding.top;
    return Consumer<PlaylistProvider>(
      builder: (_, provider, __) {
        return LayoutBuilder(
          builder: (_, constraints) {
            final contentWidth = constraints.maxWidth > 600 ? 600.0 : constraints.maxWidth;
            return RefreshIndicator(
              onRefresh: () async {
                await provider.fetchTopPlaylists();
                await _loadRecommended();
              },
              child: CustomScrollView(
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SearchHeaderDelegate(topSafe: topSafe),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      width: contentWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                            _buildSongList(_recommended, '新歌推荐', onEnd: () => _musicService.getTopSongs()),
                          if (_cardSongs[1]?.isNotEmpty ?? false)
                            _buildSongList(_cardSongs[1]!, _cardNames[1] ?? '私人专属好歌', onEnd: () => _musicService.getCardSongs(1).then((cs) => cs.songs)),
                          if (_cardSongs[2]?.isNotEmpty ?? false)
                            _buildSongList(_cardSongs[2]!, _cardNames[2] ?? '经典怀旧金曲', onEnd: () => _musicService.getCardSongs(2).then((cs) => cs.songs)),
                          if (_cardSongs[3]?.isNotEmpty ?? false)
                            _buildSongList(_cardSongs[3]!, _cardNames[3] ?? '热门好歌精选', onEnd: () => _musicService.getCardSongs(3).then((cs) => cs.songs)),
                          if (_cardSongs[4]?.isNotEmpty ?? false)
                            _buildSongList(_cardSongs[4]!, _cardNames[4] ?? '小众宝藏佳作', onEnd: () => _musicService.getCardSongs(4).then((cs) => cs.songs)),
                          if (_cardSongs[5]?.isNotEmpty ?? false)
                            _buildSongList(_cardSongs[5]!, _cardNames[5] ?? '潮流尝鲜', onEnd: () => _musicService.getCardSongs(5).then((cs) => cs.songs)),
                          if (_cardSongs[6]?.isNotEmpty ?? false)
                            _buildSongList(_cardSongs[6]!, _cardNames[6] ?? 'VIP专属推荐', onEnd: () => _musicService.getCardSongs(6).then((cs) => cs.songs)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topSafe;

  const _SearchHeaderDelegate({required this.topSafe});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    return Container(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      padding: EdgeInsets.only(top: topSafe + 8, bottom: 8),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: Material(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const SearchScreen(),
                      transitionsBuilder: (_, animation, __, child) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, -0.3),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          )),
                          child: child,
                        );
                      },
                      transitionDuration: const Duration(milliseconds: 300),
                    ),
                  );
                },
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
          IconButton(
            icon: Icon(auth.isLoggedIn ? Icons.person : Icons.person_outline,
                color: cs.onSurfaceVariant),
            onPressed: () {
              if (!auth.isLoggedIn) Navigator.pushNamed(context, '/login');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 56 + topSafe + 16;

  @override
  double get minExtent => 56 + topSafe + 16;

  @override
  bool shouldRebuild(covariant _SearchHeaderDelegate oldDelegate) {
    return oldDelegate.topSafe != topSafe;
  }
}

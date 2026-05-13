import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import '../models/song.dart';
import '../widgets/tablet_scaffold.dart';
import '../utils/responsive.dart';
import '../services/music_service.dart';
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
  Map<String, dynamic>? _latestListen;
  bool _showContinueBanner = false;
  final Map<int, List<Song>> _cardSongs = {};
  final Map<int, String> _cardNames = {};

  SliverGridDelegateWithFixedCrossAxisCount _gridDelegate(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount;
    if (width > 900) crossAxisCount = 6;
    else if (width > 600) crossAxisCount = 5;
    else if (width > 400) crossAxisCount = 4;
    else crossAxisCount = 3;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      childAspectRatio: 0.75,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
    );
  }

  Widget _buildCardGrid(int cardId, List<Song> songs, String title) {
    if (songs.isEmpty) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: tt.titleLarge),
        ),
        SizedBox(
          height: 400,
          child: GridView.builder(
            gridDelegate: _gridDelegate(context),
            itemCount: songs.length,
            itemBuilder: (_, i) {
              final song = songs[i];
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.read<PlayerProvider>().playSong(song, playlist: songs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Hero(
                        tag: 'album_art_${song.hash ?? song.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: song.albumCoverUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: song.albumCoverUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(color: cs.surfaceContainerHighest),
                                  errorWidget: (_, __, ___) => Container(color: cs.surfaceContainerHighest, child: const Icon(Icons.music_note)),
                                )
                              : Container(color: cs.surfaceContainerHighest, child: const Icon(Icons.music_note)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodySmall),
                    Text(song.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
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
    } catch (_) {}
  }

  Future<void> _loadCardSongs() async {
    final futures = <int, Future<Map<String, dynamic>>>{};
    for (int id = 1; id <= 6; id++) {
      futures[id] = _musicService.getCardSongs(id).catchError((_) => <String, dynamic>{});
    }
    final results = await Future.wait(futures.values);
    if (mounted) {
      int id = 1;
      for (final data in results) {
        _cardNames[id] = data['rec_desc'] ?? _cardTitles[id] ?? '';
        _cardSongs[id] = (data['songs'] as List<dynamic>?)?.cast<Song>() ?? [];
        id++;
      }
    }
  }

  Future<void> _checkLatestListen() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    try {
      final latest = await _musicService.getLatestListen();
      if (latest != null && latest['info'] != null && mounted) {
        setState(() {
          _latestListen = latest;
          _showContinueBanner = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _continueListen() async {
    if (_latestListen == null) return;
    final info = _latestListen!['info'] as Map<String, dynamic>;
    final song = Song.fromTrackJson(info);
    final position = Duration(seconds: _latestListen!['position'] as int? ?? 0);
    final player = context.read<PlayerProvider>();
    await player.playSong(song);
    if (position.inSeconds > 0) {
      await player.seek(position);
    }
    setState(() => _showContinueBanner = false);
  }

  @override
  Widget build(BuildContext context) {
    final isTabletLand = Responsive.isTabletLandscape(context);

    if (isTabletLand) {
      return TabletScaffold(
        currentIndex: _currentTab,
        onTabChanged: (i) => setState(() => _currentTab = i),
        tabs: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: '发现'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
        pages: [
          _buildHome(),
          const DiscoverScreen(),
          const ProfileScreen(),
        ],
      );
    }

    return Scaffold(
      appBar: _currentTab == 0
          ? AppBar(
              title: const Text('首页'),
              actions: _appBarActions(context),
            )
          : null,
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

  List<Widget> _appBarActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.search),
        tooltip: '搜索',
        onPressed: () => Navigator.pushNamed(context, '/search'),
      ),
      Consumer<AuthProvider>(
        builder: (_, auth, __) => IconButton(
          icon: Icon(auth.isLoggedIn ? Icons.person : Icons.person_outline),
          tooltip: auth.isLoggedIn ? '个人中心' : '登录',
          onPressed: () {
            if (!auth.isLoggedIn) Navigator.pushNamed(context, '/login');
          },
        ),
      ),
    ];
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
          child: ListView(
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
                      _latestListen!['info']?['name'] ?? '继续播放',
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
                        onPressed: () {},
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
              if (_recommended.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('新歌推荐', style: tt.titleLarge),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    height: 400,
                    child: GridView.builder(
                      gridDelegate: _gridDelegate(context),
                      itemCount: _recommended.length,
                      itemBuilder: (_, i) {
                        final song = _recommended[i];
                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => context.read<PlayerProvider>().playSong(song, playlist: _recommended),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 1,
                                child: Hero(
                                  tag: 'album_art_${song.hash ?? song.id}',
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: song.albumCoverUrl != null
                                      ? CachedNetworkImage(
                                          imageUrl: song.albumCoverUrl!,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(color: cs.surfaceContainerHighest),
                                          errorWidget: (_, __, ___) => Container(color: cs.surfaceContainerHighest, child: const Icon(Icons.music_note)),
                                        )
                                      : Container(color: cs.surfaceContainerHighest, child: const Icon(Icons.music_note)),
                                ),
                              ),
                              ),
                              const SizedBox(height: 4),
                              Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodySmall),
                              Text(song.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
              if (_cardSongs[1]?.isNotEmpty ?? false)
                _buildCardGrid(1, _cardSongs[1]!, _cardNames[1] ?? '私人专属好歌'),
              if (_cardSongs[2]?.isNotEmpty ?? false)
                _buildCardGrid(2, _cardSongs[2]!, _cardNames[2] ?? '经典怀旧金曲'),
              if (_cardSongs[3]?.isNotEmpty ?? false)
                _buildCardGrid(3, _cardSongs[3]!, _cardNames[3] ?? '热门好歌精选'),
              if (_cardSongs[4]?.isNotEmpty ?? false)
                _buildCardGrid(4, _cardSongs[4]!, _cardNames[4] ?? '小众宝藏佳作'),
              if (_cardSongs[5]?.isNotEmpty ?? false)
                _buildCardGrid(5, _cardSongs[5]!, _cardNames[5] ?? '潮流尝鲜'),
              if (_cardSongs[6]?.isNotEmpty ?? false)
                _buildCardGrid(6, _cardSongs[6]!, _cardNames[6] ?? 'VIP专属推荐'),
            ],
          ),
        );
      },
    );
  }
}

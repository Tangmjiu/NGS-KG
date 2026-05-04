import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import '../models/song.dart';
import '../widgets/playlist_card.dart';
import '../widgets/tablet_scaffold.dart';
import '../widgets/song_tile.dart';
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
  List<Map<String, dynamic>> _banners = [];
  List<Song> _recommended = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaylistProvider>().fetchTopPlaylists();
    });
    _loadBanners();
    _loadRecommended();
  }

  Future<void> _loadBanners() async {
    try {
      final banners = await _musicService.getYuekuBanner();
      if (mounted) {
        final list = banners.isNotEmpty ? banners : await _musicService.getTopPlaylists(limit: 5);
        if (list.isNotEmpty && list[0] is Map) {
          setState(() => _banners = list.cast<Map<String, dynamic>>());
        }
      }
    } catch (_) {}
  }

  Future<void> _loadRecommended() async {
    try {
      final songs = await _musicService.getTopSongs();
      if (mounted) setState(() => _recommended = songs.take(10).toList());
    } catch (_) {}
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
          _buildPage(AppBar(
            title: const Text('首页'),
            actions: _appBarActions(context),
          ), _buildHome()),
          _buildPage(null, const DiscoverScreen()),
          _buildPage(null, const ProfileScreen()),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: '发现'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }

  List<Widget> _appBarActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.search),
        onPressed: () => Navigator.pushNamed(context, '/search'),
      ),
      Consumer<AuthProvider>(
        builder: (_, auth, __) => IconButton(
          icon: Icon(auth.isLoggedIn ? Icons.person : Icons.person_outline),
          onPressed: () {
            if (!auth.isLoggedIn) Navigator.pushNamed(context, '/login');
          },
        ),
      ),
    ];
  }

  Widget _buildPage(AppBar? appBar, Widget body) {
    if (appBar == null) return body;
    return Column(children: [appBar, Expanded(child: body)]);
  }

  Widget _buildHome() {
    return Consumer<PlaylistProvider>(
      builder: (_, provider, __) {
        return RefreshIndicator(
          onRefresh: () async {
            await provider.fetchTopPlaylists();
            await _loadBanners();
            await _loadRecommended();
          },
          child: ListView(
            children: [
              // Banner
              if (_banners.isNotEmpty) ...[
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(8),
                    itemCount: _banners.length,
                    itemBuilder: (_, i) {
                      final item = _banners[i];
                      final imgUrl = (item['imgurl'] ?? item['banner'] ?? item['coverImgUrl'] ?? '') as String;
                      return Container(
                        width: 300,
                        margin: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: imgUrl.replaceAll('{size}', '720'),
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: Colors.grey[850]),
                            errorWidget: (_, __, ___) => Container(color: Colors.grey[850], child: const Icon(Icons.music_note)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              // 推荐歌单
              if (provider.topPlaylists.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('推荐歌单',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                            final args = pl.globalCollectionId != null
                                ? {'gcId': pl.globalCollectionId, 'name': pl.name}
                                : {'id': pl.id, 'name': pl.name};
                            Navigator.pushNamed(context, '/playlist/detail', arguments: args);
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
                                          placeholder: (_, __) => Container(color: Colors.grey[850], width: 130, height: 130),
                                          errorWidget: (_, __, ___) => Container(color: Colors.grey[850], width: 130, height: 130, child: const Icon(Icons.playlist_play)),
                                        )
                                      : Container(color: Colors.grey[850], width: 130, height: 130, child: const Icon(Icons.playlist_play)),
                                ),
                                const SizedBox(height: 4),
                                Text(pl.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              // 推荐歌曲
              if (_recommended.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('新歌推荐',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                ...List.generate(_recommended.length, (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SongTile(song: _recommended[i],
                    onTap: (s) => context.read<PlayerProvider>().playSong(s, playlist: _recommended),
                  ),
                )),
              ],
            ],
          ),
        );
      },
    );
  }
}

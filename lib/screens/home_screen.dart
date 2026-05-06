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
  List<Song> _recommended = [];
  Map<String, dynamic>? _latestListen;
  bool _showContinueBanner = false;
  final Map<int, List<Song>> _cardSongs = {};
  final Map<int, String> _cardNames = {};
  bool _loadingCards = true;

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
          setState(() {
            _cardNames[id] = data['rec_desc'] ?? _cardTitles[id] ?? '';
            _cardSongs[id] = data['songs'];
          });
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _loadingCards = false);
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
            await _loadRecommended();
          },
          child: ListView(
            children: [
              // 继续播放弹窗
              if (_showContinueBanner && _latestListen != null)
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
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
                          onPressed: _continueListen,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _showContinueBanner = false),
                        ),
                      ],
                    ),
                    onTap: _continueListen,
                  ),
                ),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    height: 400,
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _recommended.length,
                      itemBuilder: (_, i) {
                        final song = _recommended[i];
                        return GestureDetector(
                          onTap: () => context.read<PlayerProvider>().playSong(song, playlist: _recommended),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: song.albumCoverUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: song.albumCoverUrl!,
                                        width: double.infinity,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(color: Colors.grey[800], height: 80),
                                        errorWidget: (_, __, ___) => Container(color: Colors.grey[800], height: 80, child: const Icon(Icons.music_note)),
                                      )
                                    : Container(color: Colors.grey[800], height: 80, child: const Icon(Icons.music_note)),
                              ),
                              const SizedBox(height: 4),
                              Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                              Text(song.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
              // 私人专属好歌 card_id=1
              if (_cardSongs[1]?.isNotEmpty ?? false) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(_cardNames[1] ?? '私人专属好歌', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  height: 400,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _cardSongs[1]!.length,
                    itemBuilder: (_, i) {
                      final song = _cardSongs[1]![i];
                      return GestureDetector(
                        onTap: () => context.read<PlayerProvider>().playSong(song, playlist: _cardSongs[1]!),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: song.albumCoverUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: song.albumCoverUrl!,
                                      width: double.infinity,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: Colors.grey[800], height: 80),
                                      errorWidget: (_, __, ___) => Container(color: Colors.grey[800], height: 80, child: const Icon(Icons.music_note)),
                                    )
                                  : Container(color: Colors.grey[800], height: 80, child: const Icon(Icons.music_note)),
                            ),
                            const SizedBox(height: 4),
                            Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                            Text(song.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              // 经典怀旧金曲 card_id=2
              if (_cardSongs[2]?.isNotEmpty ?? false) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(_cardNames[2] ?? '经典怀旧金曲', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  height: 400,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _cardSongs[2]!.length,
                    itemBuilder: (_, i) {
                      final song = _cardSongs[2]![i];
                      return GestureDetector(
                        onTap: () => context.read<PlayerProvider>().playSong(song, playlist: _cardSongs[2]!),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: song.albumCoverUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: song.albumCoverUrl!,
                                      width: double.infinity,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: Colors.grey[800], height: 80),
                                      errorWidget: (_, __, ___) => Container(color: Colors.grey[800], height: 80, child: const Icon(Icons.music_note)),
                                    )
                                  : Container(color: Colors.grey[800], height: 80, child: const Icon(Icons.music_note)),
                            ),
                            const SizedBox(height: 4),
                            Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                            Text(song.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              // 热门好歌精选 card_id=3
              if (_cardSongs[3]?.isNotEmpty ?? false) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(_cardNames[3] ?? '热门好歌精选', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  height: 400,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _cardSongs[3]!.length,
                    itemBuilder: (_, i) {
                      final song = _cardSongs[3]![i];
                      return GestureDetector(
                        onTap: () => context.read<PlayerProvider>().playSong(song, playlist: _cardSongs[3]!),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: song.albumCoverUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: song.albumCoverUrl!,
                                      width: double.infinity,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: Colors.grey[800], height: 80),
                                      errorWidget: (_, __, ___) => Container(color: Colors.grey[800], height: 80, child: const Icon(Icons.music_note)),
                                    )
                                  : Container(color: Colors.grey[800], height: 80, child: const Icon(Icons.music_note)),
                            ),
                            const SizedBox(height: 4),
                            Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                            Text(song.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              // 小众宝藏佳作 card_id=4
              if (_cardSongs[4]?.isNotEmpty ?? false) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(_cardNames[4] ?? '小众宝藏佳作', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  height: 400,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _cardSongs[4]!.length,
                    itemBuilder: (_, i) {
                      final song = _cardSongs[4]![i];
                      return GestureDetector(
                        onTap: () => context.read<PlayerProvider>().playSong(song, playlist: _cardSongs[4]!),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: song.albumCoverUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: song.albumCoverUrl!,
                                      width: double.infinity,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: Colors.grey[800], height: 80),
                                      errorWidget: (_, __, ___) => Container(color: Colors.grey[800], height: 80, child: const Icon(Icons.music_note)),
                                    )
                                  : Container(color: Colors.grey[800], height: 80, child: const Icon(Icons.music_note)),
                            ),
                            const SizedBox(height: 4),
                            Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                            Text(song.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              // 潮流尝鲜 card_id=5
              if (_cardSongs[5]?.isNotEmpty ?? false) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(_cardNames[5] ?? '潮流尝鲜', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  height: 400,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _cardSongs[5]!.length,
                    itemBuilder: (_, i) {
                      final song = _cardSongs[5]![i];
                      return GestureDetector(
                        onTap: () => context.read<PlayerProvider>().playSong(song, playlist: _cardSongs[5]!),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: song.albumCoverUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: song.albumCoverUrl!,
                                      width: double.infinity,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: Colors.grey[800], height: 80),
                                      errorWidget: (_, __, ___) => Container(color: Colors.grey[800], height: 80, child: const Icon(Icons.music_note)),
                                    )
                                  : Container(color: Colors.grey[800], height: 80, child: const Icon(Icons.music_note)),
                            ),
                            const SizedBox(height: 4),
                            Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                            Text(song.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              // VIP专属推荐 card_id=6
              if (_cardSongs[6]?.isNotEmpty ?? false) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(_cardNames[6] ?? 'VIP专属推荐', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  height: 400,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _cardSongs[6]!.length,
                    itemBuilder: (_, i) {
                      final song = _cardSongs[6]![i];
                      return GestureDetector(
                        onTap: () => context.read<PlayerProvider>().playSong(song, playlist: _cardSongs[6]!),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: song.albumCoverUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: song.albumCoverUrl!,
                                      width: double.infinity,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: Colors.grey[800], height: 80),
                                      errorWidget: (_, __, ___) => Container(color: Colors.grey[800], height: 80, child: const Icon(Icons.music_note)),
                                    )
                                  : Container(color: Colors.grey[800], height: 80, child: const Icon(Icons.music_note)),
                            ),
                            const SizedBox(height: 4),
                            Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                            Text(song.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

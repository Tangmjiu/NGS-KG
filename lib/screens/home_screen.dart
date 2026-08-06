import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/latest_listen_info.dart';
import '../services/music_service.dart';
import '../models/song_mapper.dart';
import '../utils/logger.dart';
import '../utils/theme.dart';
import 'discover_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import '../widgets/list_bottom_spacer.dart';
import '../widgets/shimmer_box.dart';
import '../widgets/expressive_cover.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  final MusicService _musicService = MusicService();
  List<Song> _recommended = [];
  List<Song> _dailySongs = [];
  bool _dailyLoading = true;
  LatestListenInfo? _latestListen;
  bool _showContinueBanner = false;
  final Map<int, List<Song>> _cardSongs = {};
  final Map<int, String> _cardNames = {};

  // ─── 推荐歌单轮播状态 ───
  final PageController _playlistPageController = PageController();
  Timer? _playlistTimer;
  int _playlistPage = 0;
  int _carouselTotal = 0;

  /// 3行/列 缩略图列表，水平滑动
  Widget _buildSongList(List<Song> songs, String title,
      {Future<List<Song>> Function()? onEnd}) {
    if (songs.isEmpty) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final player = context.read<PlayerProvider>();

    // 每 3 首一组
    final chunks = <List<Song>>[];
    for (var i = 0; i < songs.length; i += 3) {
      final end = (i + 3 > songs.length) ? songs.length : i + 3;
      chunks.add(songs.sublist(i, end));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(title,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        ),
        SizedBox(
          height: 204,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollCacheExtent: const ScrollCacheExtent.pixels(300),
            itemCount: chunks.length,
            itemBuilder: (_, i) {
              final chunk = chunks[i];
              return M3StaggeredFadeIn(
                index: i,
                child: Container(
                  width: 260,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: AppShape.lg,
                  ),
                  child: Column(
                    children: List.generate(chunk.length, (j) {
                      final song = chunk[j];
                      final flatIdx = i * 3 + j;
                      return Expanded(
                        child: M3PressScale(
                          scaleDown: 0.95,
                          child: InkWell(
                            borderRadius: (j == 0)
                                ? const BorderRadius.vertical(
                                    top: Radius.circular(24))
                                : (j == chunk.length - 1)
                                    ? const BorderRadius.vertical(
                                        bottom: Radius.circular(24))
                                    : null,
                            onTap: () {
                              player.playlistEndProvider = onEnd;
                              player.playSong(song,
                                  playlist: songs.sublist(flatIdx));
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: AppShape.sm,
                                    child: song.thumbnailCoverUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: song.thumbnailCoverUrl!,
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 88,
                                            memCacheHeight: 88,
                                            placeholder: (_, __) => Container(
                                                width: 44,
                                                height: 44,
                                                color: cs.surface),
                                            errorWidget: (_, __, ___) =>
                                                Container(
                                                    width: 44,
                                                    height: 44,
                                                    color: cs.surface,
                                                    child: const Icon(
                                                        Icons
                                                            .music_note_rounded,
                                                        size: 20)),
                                          )
                                        : Container(
                                            width: 44,
                                            height: 44,
                                            color: cs.surface,
                                            child: const Icon(
                                                Icons.music_note_rounded,
                                                size: 20)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(song.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w500)),
                                        const SizedBox(height: 2),
                                        Text(song.artistDisplay,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                    color:
                                                        cs.onSurfaceVariant)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDailyRecommend() {
    if (_dailyLoading) {
      return _buildDailyShimmer();
    }
    if (_dailySongs.isEmpty) return const SizedBox.shrink();
    return _buildSongList(_dailySongs, '每日推荐',
        onEnd: () => _musicService.getDailyRecommend());
  }

  Widget _buildDailyShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: ShimmerBar(width: 100, height: 24, borderRadius: AppShape.xs),
        ),
        SizedBox(
          height: 156,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 4,
            itemBuilder: (_, i) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: AppShape.md,
                  child: SizedBox(
                    width: 190,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ShimmerBox(borderRadius: BorderRadius.zero),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            children: List.generate(3, (j) {
                              return const Expanded(
                                child: Row(
                                  children: [
                                    ShimmerBox(
                                        width: 36,
                                        height: 36,
                                        borderRadius: AppShape.xs),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          ShimmerBar(width: 100, height: 12),
                                          SizedBox(height: 4),
                                          ShimmerBar(width: 60, height: 10),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 推荐歌单 M3 轮播（对标 Rhythm HomeScreen Carousel）
  ///
  /// 横版 Hero 大卡 + 4s 自动轮播 + 指示点 + 渐变遮罩；点击进入歌单详情。
  Widget _buildPlaylistCarousel(List<Playlist> playlists) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    _ensureCarouselTimer(playlists.length);

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _playlistPageController,
            itemCount: playlists.length,
            onPageChanged: (i) => setState(() => _playlistPage = i),
            itemBuilder: (_, i) {
              final pl = playlists[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: M3PressScale(
                  scaleDown: 0.97,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/playlist/detail',
                          arguments: {
                            'gcId': pl.globalCollectionId ??
                                'collection_3_${pl.createUserId}_${pl.id}_0',
                            'name': pl.name,
                          });
                    },
                    child: ExpressiveCover(
                      animate: true,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 封面
                          if (pl.coverUrl != null && pl.coverUrl!.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: pl.coverUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: cs.surfaceContainerHighest),
                              errorWidget: (_, __, ___) => Container(
                                  color: cs.surfaceContainerHighest,
                                  child: Icon(Icons.playlist_play,
                                      size: 40, color: cs.primary)),
                            )
                          else
                            Container(
                              color: cs.primaryContainer,
                              child: Icon(Icons.playlist_play,
                                  size: 40, color: cs.onPrimaryContainer),
                            ),
                          // 底部渐变遮罩，保证文字可读性
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black54],
                                stops: [0.45, 1.0],
                              ),
                            ),
                          ),
                          // 歌单信息
                          Positioned(
                            left: 14,
                            right: 14,
                            bottom: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  pl.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                if (pl.trackCount > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${pl.trackCount} 首',
                                    style: tt.bodySmall?.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // 指示点：当前页拉长为胶囊并高亮；FittedBox 防御极端数量溢出
        SizedBox(
          height: 6,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(playlists.length, (i) {
                  final active = i == _playlistPage % playlists.length;
                  return AnimatedContainer(
                    duration: AppMotion.dShort4,
                    curve: AppMotion.emphasizedDecelerate,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? cs.primary : cs.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
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

  static const _cardTitlesYouth = {
    3014: '喜欢这首歌的 TA 也喜欢',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaylistProvider>().fetchTopPlaylists();
      _loadRecommended();
      _loadDailyRecommend();
      _loadCardSongs();
      _checkLatestListen();
      context.read<AuthProvider>().addListener(_onAuthChanged);
    });
  }

  @override
  void dispose() {
    _playlistTimer?.cancel();
    _playlistPageController.dispose();
    try {
      context.read<AuthProvider>().removeListener(_onAuthChanged);
    } catch (_) {}
    super.dispose();
  }

  /// 启动/维护推荐歌单轮播自动播放（4s 循环）
  ///
  /// 幂等：Timer 已存在时不重复创建；列表刷新后通过 [_carouselTotal]
  /// 感知最新数量，避免闭包捕获过期长度。
  void _ensureCarouselTimer(int count) {
    _carouselTotal = count;
    if (count <= 1) {
      _playlistTimer?.cancel();
      _playlistTimer = null;
      return;
    }
    // 列表刷新后当前页可能越界，回跳第 0 页
    if (_playlistPage >= count && _playlistPageController.hasClients) {
      _playlistPageController.jumpToPage(0);
    }
    if (_playlistTimer != null) return;
    _playlistTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_playlistPageController.hasClients) return;
      final next = (_playlistPage + 1) % _carouselTotal;
      _playlistPageController.animateToPage(
        next,
        duration: AppMotion.dMedium2,
        curve: AppMotion.emphasizedDecelerate,
      );
    });
  }

  bool _wasLoggedIn = false;

  void _onAuthChanged() {
    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    if (loggedIn && !_wasLoggedIn) {
      _checkLatestListen();
    }
    _wasLoggedIn = loggedIn;
  }

  Future<void> _loadRecommended() async {
    try {
      final songs = await _musicService.getTopSongs();
      if (mounted) setState(() => _recommended = songs.take(10).toList());
    } catch (e, s) {
      Log.e('home_screen', 'error', e, s);
    }
  }

  Future<void> _loadDailyRecommend() async {
    setState(() => _dailyLoading = true);
    try {
      final songs = await _musicService.getDailyRecommend();
      if (mounted) {
        setState(() {
          _dailySongs = songs;
          _dailyLoading = false;
        });
      }
    } catch (e, s) {
      Log.e('home_screen', 'error', e, s);
      if (mounted) {
        setState(() => _dailyLoading = false);
      }
    }
  }

  Future<void> _loadCardSongs() async {
    final cardIds = [1, 2, 3, 4, 5, 6, 3014];
    final futures = <Future<void>>[];
    for (final id in cardIds) {
      futures.add((() async {
        try {
          final bool isYouth = id > 1000;
          final data = isYouth
              ? await _musicService.getCardSongsYouth(id, pagesize: 20)
              : await _musicService.getCardSongs(id);
          if (!mounted) return;
          final title = isYouth
              ? (_cardTitlesYouth[id] ?? '推荐')
              : (_cardTitles[id] ?? '');
          _cardNames[id] = data.recDesc.isNotEmpty ? data.recDesc : title;
          _cardSongs[id] = data.songs;
        } catch (e, s) {
          Log.e('home_screen', 'error', e, s);
        }
      })());
    }
    await Future.wait(futures);
    if (mounted) setState(() {});
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
    } catch (e, s) {
      Log.e('home_screen', 'error', e, s);
    }
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

  void _refreshProfile() {
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn && auth.user?.userId != null) {
      context.read<PlaylistProvider>().fetchUserPlaylist(auth.user!.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 局部注入对 MiniBar 出现时的 MediaQuery padding.bottom 避让。
    // 在这里仅包裹 body 而不包裹整个 Scaffold，防止 Scaffold 将 bottomNavigationBar 抬高导致与 MiniBar 重叠。
    // 精确选择：只订阅 MiniPlayer 显隐条件，避免播放进度导致整个首页重建
    final showMini = context.select<PlayerProvider, bool>(
      (p) =>
          p.currentSong != null &&
          !p.isPlayerScreenVisible &&
          !p.isMiniPlayerDismissed,
    );

    final mq = MediaQuery.of(context);
    final childMediaQuery = showMini
        ? mq.copyWith(
            padding: mq.padding.copyWith(
              bottom: mq.padding.bottom + 76.0,
            ),
            viewPadding: mq.viewPadding.copyWith(
              bottom: mq.viewPadding.bottom + 76.0,
            ),
          )
        : mq;

    return Scaffold(
      body: MediaQuery(
        data: childMediaQuery,
        child: AnimatedSwitcher(
          duration: AppMotion.dMedium2,
          switchInCurve: AppMotion.emphasizedDecelerate,
          switchOutCurve: AppMotion.emphasizedAccelerate,
          transitionBuilder: (child, animation) {
            return M3FadeThroughTransition(animation: animation, child: child);
          },
          // 按需构建当前 tab，避免 DiscoverScreen / ProfileScreen 在后台同时构建/重建。
          // 如需保留 tab 状态，可改用 PageStorage 包裹。
          child: _currentTab == 0
              ? _buildHome()
              : _currentTab == 1
                  ? const DiscoverScreen()
                  : const ProfileScreen(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (i) {
          setState(() => _currentTab = i);
          if (i == 2) _refreshProfile();
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '首页'),
          NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: '发现'),
          NavigationDestination(
              icon: Icon(Icons.person_outlined),
              selectedIcon: Icon(Icons.person),
              label: '我的'),
        ],
      ),
    );
  }

  Widget _buildHome() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final topSafe = MediaQuery.of(context).padding.top;
    final auth = context.watch<AuthProvider>();
    return Consumer<PlaylistProvider>(
      builder: (_, provider, __) {
        return LayoutBuilder(
          builder: (_, constraints) {
            final contentWidth =
                constraints.maxWidth > 600 ? 600.0 : constraints.maxWidth;
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
                      topSafe: topSafe,
                      isLoggedIn: auth.isLoggedIn,
                      avatarUrl: auth.user?.avatarUrl,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      width: contentWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedSwitcher(
                            duration: AppMotion.dMedium2,
                            switchInCurve: AppMotion.emphasizedDecelerate,
                            switchOutCurve: AppMotion.emphasizedAccelerate,
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SizeTransition(
                                  sizeFactor: animation,
                                  axisAlignment: -1.0,
                                  child: child,
                                ),
                              );
                            },
                            child: (_showContinueBanner &&
                                    _latestListen != null)
                                ? (() {
                                    final info = _latestListen?.info;
                                    final coverUrl =
                                        info?['cover'] as String? ??
                                            info?['album_cover'] as String? ??
                                            info?['imgUrl'] as String? ??
                                            info?['album_logo'] as String?;
                                    final rawName = info?['name'] as String? ??
                                        info?['songname'] as String? ??
                                        '继续播放';
                                    final songName = rawName.replaceAll(
                                        RegExp(r'\.(mp3|flac|wav|m4a)$',
                                            caseSensitive: false),
                                        '');
                                    final artist =
                                        info?['singername'] as String? ?? '';
                                    final device =
                                        _latestListen?.deviceLabel ?? '';
                                    final deviceText = artist.isNotEmpty
                                        ? '$artist · $device'
                                        : device;

                                    return Padding(
                                      key: const ValueKey(
                                          'continue_play_banner'),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      child: M3PressScale(
                                        scaleDown: 0.98,
                                        child: Card(
                                          elevation: 0,
                                          color: cs.surfaceContainerHigh,
                                          margin: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: AppShape.lg,
                                            side: BorderSide(
                                              color: cs.outlineVariant
                                                  .withValues(alpha: 0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: InkWell(
                                            borderRadius: AppShape.lg,
                                            onTap: _continueListen,
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Row(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius: AppShape.sm,
                                                    child: coverUrl != null &&
                                                            coverUrl.isNotEmpty
                                                        ? CachedNetworkImage(
                                                            imageUrl: coverUrl
                                                                .replaceAll(
                                                                    '{size}',
                                                                    '240'),
                                                            width: 48,
                                                            height: 48,
                                                            fit: BoxFit.cover,
                                                            placeholder:
                                                                (_, __) =>
                                                                    Container(
                                                              width: 48,
                                                              height: 48,
                                                              color: cs
                                                                  .surfaceContainerHighest,
                                                              child: Icon(
                                                                  Icons
                                                                      .music_note_rounded,
                                                                  color: cs
                                                                      .primary,
                                                                  size: 24),
                                                            ),
                                                            errorWidget:
                                                                (_, __, ___) =>
                                                                    Container(
                                                              width: 48,
                                                              height: 48,
                                                              color: cs
                                                                  .surfaceContainerHighest,
                                                              child: Icon(
                                                                  Icons
                                                                      .music_note_rounded,
                                                                  color: cs
                                                                      .primary,
                                                                  size: 24),
                                                            ),
                                                          )
                                                        : Container(
                                                            width: 48,
                                                            height: 48,
                                                            color: cs
                                                                .surfaceContainerHighest,
                                                            child: Icon(
                                                                Icons
                                                                    .music_note_rounded,
                                                                color:
                                                                    cs.primary,
                                                                size: 24),
                                                          ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          songName,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: tt.titleMedium
                                                              ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: cs.onSurface,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        Text(
                                                          deviceText,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: tt.bodySmall
                                                              ?.copyWith(
                                                            color: cs
                                                                .onSurfaceVariant,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Material(
                                                        color: cs.primary,
                                                        shape:
                                                            const CircleBorder(),
                                                        child: InkWell(
                                                          customBorder:
                                                              const CircleBorder(),
                                                          onTap:
                                                              _continueListen,
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(8),
                                                            child: Icon(
                                                                Icons
                                                                    .play_arrow_rounded,
                                                                color: cs
                                                                    .onPrimary,
                                                                size: 20),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      IconButton(
                                                        icon: Icon(
                                                            Icons.close_rounded,
                                                            color: cs
                                                                .onSurfaceVariant,
                                                            size: 20),
                                                        onPressed: () =>
                                                            setState(() =>
                                                                _showContinueBanner =
                                                                    false),
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  })()
                                : const SizedBox.shrink(
                                    key: ValueKey('continue_play_empty')),
                          ),
                          if (provider.topPlaylists.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('推荐歌单', style: tt.headlineSmall),
                                  TextButton(
                                    onPressed: () => Navigator.pushNamed(
                                        context, '/recommended/playlists'),
                                    child: const Text('更多'),
                                  ),
                                ],
                              ),
                            ),
                            // 只轮播前 5 个推荐歌单，避免页数/指示点过多导致溢出
                            _buildPlaylistCarousel(
                                provider.topPlaylists.take(5).toList()),
                          ],
                          if (_dailyLoading || _dailySongs.isNotEmpty)
                            _buildDailyRecommend(),
                          if (_recommended.isNotEmpty)
                            _buildSongList(_recommended, '新歌推荐',
                                onEnd: () => _musicService.getTopSongs()),
                          if (_cardSongs[1]?.isNotEmpty ?? false)
                            _buildSongList(
                                _cardSongs[1]!, _cardNames[1] ?? '私人专属好歌',
                                onEnd: () => _musicService
                                    .getCardSongs(1)
                                    .then((cs) => cs.songs)),
                          if (_cardSongs[2]?.isNotEmpty ?? false)
                            _buildSongList(
                                _cardSongs[2]!, _cardNames[2] ?? '经典怀旧金曲',
                                onEnd: () => _musicService
                                    .getCardSongs(2)
                                    .then((cs) => cs.songs)),
                          if (_cardSongs[3]?.isNotEmpty ?? false)
                            _buildSongList(
                                _cardSongs[3]!, _cardNames[3] ?? '热门好歌精选',
                                onEnd: () => _musicService
                                    .getCardSongs(3)
                                    .then((cs) => cs.songs)),
                          if (_cardSongs[4]?.isNotEmpty ?? false)
                            _buildSongList(
                                _cardSongs[4]!, _cardNames[4] ?? '小众宝藏佳作',
                                onEnd: () => _musicService
                                    .getCardSongs(4)
                                    .then((cs) => cs.songs)),
                          if (_cardSongs[5]?.isNotEmpty ?? false)
                            _buildSongList(
                                _cardSongs[5]!, _cardNames[5] ?? '潮流尝鲜',
                                onEnd: () => _musicService
                                    .getCardSongs(5)
                                    .then((cs) => cs.songs)),
                          if (_cardSongs[6]?.isNotEmpty ?? false)
                            _buildSongList(
                                _cardSongs[6]!, _cardNames[6] ?? 'VIP专属推荐',
                                onEnd: () => _musicService
                                    .getCardSongs(6)
                                    .then((cs) => cs.songs)),
                          if (_cardSongs[3014]?.isNotEmpty ?? false)
                            _buildSongList(_cardSongs[3014]!,
                                _cardNames[3014] ?? '喜欢这首歌的 TA 也喜欢',
                                onEnd: () => _musicService
                                    .getCardSongsYouth(3014)
                                    .then((cs) => cs.songs)),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: ListBottomSpacer(isHome: true),
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
  final bool isLoggedIn;
  final String? avatarUrl;

  const _SearchHeaderDelegate({
    required this.topSafe,
    required this.isLoggedIn,
    this.avatarUrl,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final searchBg = Color.alphaBlend(
      cs.onSurface.withValues(alpha: isDark ? 0.08 : 0.05),
      cs.surface,
    );

    return Container(
      height: maxExtent,
      color: cs.surface,
      padding: EdgeInsets.only(top: topSafe + 8, bottom: 8),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: M3PressScale(
              child: Material(
                color: searchBg,
                borderRadius: AppShape.full,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  borderRadius: AppShape.full,
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
                              curve: AppMotion.emphasizedDecelerate,
                            )),
                            child: FadeTransition(
                              opacity: CurvedAnimation(
                                parent: animation,
                                curve: AppMotion.emphasizedDecelerate,
                              ),
                              child: child,
                            ),
                          );
                        },
                        transitionDuration: AppMotion.dMedium2,
                      ),
                    );
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.search,
                            size: 20, color: cs.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text('搜索歌曲、歌手、歌单',
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isLoggedIn && avatarUrl != null && avatarUrl!.isNotEmpty)
            M3PressScale(
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/user/profile'),
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: CachedNetworkImageProvider(avatarUrl!),
                  onBackgroundImageError: (_, __) {},
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(isLoggedIn ? Icons.person : Icons.person_outline,
                  color: cs.onSurfaceVariant),
              onPressed: () {
                if (!isLoggedIn) Navigator.pushNamed(context, '/login');
                if (isLoggedIn) Navigator.pushNamed(context, '/user/profile');
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
    return oldDelegate.topSafe != topSafe ||
        oldDelegate.isLoggedIn != isLoggedIn;
  }
}

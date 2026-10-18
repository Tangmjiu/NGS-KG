// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/latest_listen_info.dart';
import '../models/song.dart';
import '../models/song_mapper.dart';
import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../ui/app_ui.dart';
import '../ui/components/player_bottom_padding.dart';
import '../ui/components/app_navigation.dart';
import '../ui/components/app_tab_view.dart';
import 'discover/sections/discover_media_rail.dart';
import 'discover/sections/discover_playlist_row.dart';
import 'discover_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  final MusicService? musicService;

  const HomeScreen({super.key, this.musicService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  int _privateFmFocusRequest = 0;
  final Set<int> _visitedTabs = {0};

  void _selectTab(int index) {
    if (index == _currentTab) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _currentTab = index;
      _visitedTabs.add(index);
    });
  }

  void _openPrivateFm() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _currentTab = 1;
      _visitedTabs.add(1);
      _privateFmFocusRequest++;
    });
  }

  Widget _tab(int index) => switch (index) {
        0 => _HomeFeed(
            musicService: widget.musicService,
            onSearch: () => _selectTab(2),
            onOpenFm: _openPrivateFm,
          ),
        1 => DiscoverScreen(privateFmFocusRequest: _privateFmFocusRequest),
        2 => SearchScreen(embedded: true, musicService: widget.musicService),
        _ => LibraryScreen(musicService: widget.musicService),
      };

  @override
  Widget build(BuildContext context) {
    final showMini = context.select<PlayerProvider, bool>((player) =>
        player.currentSong != null &&
        !player.isPlayerScreenVisible &&
        !player.isMiniPlayerDismissed);
    final mq = MediaQuery.of(context);
    final bodyMediaQuery = showMini
        ? mq.copyWith(
            padding: mq.padding.copyWith(
                bottom:
                    mq.padding.bottom + AppChrome.miniPlayerExtent(context)),
            viewPadding: mq.viewPadding.copyWith(
                bottom: mq.viewPadding.bottom +
                    AppChrome.miniPlayerExtent(context)),
          )
        : mq;

    return LayoutBuilder(builder: (context, constraints) {
      final rail = AppChrome.usesRail(constraints.maxWidth);
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: rail ? AppChrome.railExtent + mq.padding.left : 0,
              child: rail
                  ? AppNavigation(
                      rail: true,
                      selectedIndex: _currentTab,
                      onSelected: _selectTab,
                    )
                  : null,
            ),
            Expanded(
              child: MediaQuery(
                data: rail
                    ? bodyMediaQuery.copyWith(
                        padding: bodyMediaQuery.padding.copyWith(left: 0),
                        viewPadding:
                            bodyMediaQuery.viewPadding.copyWith(left: 0),
                      )
                    : bodyMediaQuery,
                // 稳定的页面位置同时保留访问状态与窗口尺寸变化前的输入。
                child: AppTabView(
                  index: _currentTab,
                  children: List.generate(
                    4,
                    (index) => _visitedTabs.contains(index)
                        ? _tab(index)
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: rail
            ? null
            : AppNavigation(selectedIndex: _currentTab, onSelected: _selectTab),
      );
    });
  }
}

class _HomeFeed extends StatefulWidget {
  final MusicService? musicService;
  final VoidCallback onSearch;
  final VoidCallback onOpenFm;

  const _HomeFeed({
    this.musicService,
    required this.onSearch,
    required this.onOpenFm,
  });

  @override
  State<_HomeFeed> createState() => _HomeFeedState();
}

class _HomeFeedState extends State<_HomeFeed> {
  late final MusicService _musicService;
  late final AuthProvider _auth;
  Future<void>? _refreshInFlight;
  List<Song> _recommended = [];
  List<Song> _dailySongs = [];
  bool _loading = true;
  bool _dailyLoading = true;
  bool _wasLoggedIn = false;
  LatestListenInfo? _latestListen;
  bool _showContinueBanner = false;
  final Map<int, List<Song>> _cardSongs = {};
  final Map<int, String> _cardNames = {};

  static const _cardTitles = {
    1: '私人专属好歌',
    2: '经典怀旧金曲',
    3: '热门好歌精选',
    4: '小众宝藏佳作',
    5: '潮流尝鲜',
    6: 'VIP专属推荐',
    3014: '喜欢这首歌的 TA 也喜欢',
  };

  @override
  void initState() {
    super.initState();
    _musicService = widget.musicService ?? MusicService();
    _auth = context.read<AuthProvider>();
    _wasLoggedIn = _auth.isLoggedIn;
    _auth.addListener(_onAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (_auth.isLoggedIn && !_wasLoggedIn) _checkLatestListen();
    if (!_auth.isLoggedIn && mounted) {
      setState(() {
        _latestListen = null;
        _showContinueBanner = false;
      });
    }
    _wasLoggedIn = _auth.isLoggedIn;
  }

  Future<void> _refresh() {
    final pending = _refreshInFlight;
    if (pending != null) return pending;
    final request = Future.wait([
      context.read<PlaylistProvider>().fetchTopPlaylists(),
      _loadRecommended(),
      _loadDailyRecommend(),
      _loadCardSongs(),
      _checkLatestListen(),
    ]).then<void>((_) {}).catchError((Object error, StackTrace stack) {
      Log.e('home_screen', 'refresh error', error, stack);
    }).whenComplete(() {
      _refreshInFlight = null;
      if (mounted) setState(() => _loading = false);
    });
    _refreshInFlight = request;
    return request;
  }

  Future<void> _loadRecommended() async {
    try {
      final songs = await _musicService.getTopSongs();
      if (mounted) setState(() => _recommended = songs.take(10).toList());
    } catch (error, stack) {
      Log.e('home_screen', 'recommend error', error, stack);
    }
  }

  Future<void> _loadDailyRecommend() async {
    if (mounted) setState(() => _dailyLoading = true);
    try {
      final songs = await _musicService.getDailyRecommend();
      if (mounted) setState(() => _dailySongs = songs);
    } catch (error, stack) {
      Log.e('home_screen', 'daily recommend error', error, stack);
    } finally {
      if (mounted) setState(() => _dailyLoading = false);
    }
  }

  Future<void> _loadCardSongs() async {
    await Future.wait(_cardTitles.keys.map((id) async {
      try {
        final result = id > 1000
            ? await _musicService.getCardSongsYouth(id, pagesize: 20)
            : await _musicService.getCardSongs(id);
        if (!mounted) return;
        setState(() {
          _cardSongs[id] = result.songs;
          _cardNames[id] =
              result.recDesc.isEmpty ? _cardTitles[id]! : result.recDesc;
        });
      } catch (error, stack) {
        Log.e('home_screen', 'card songs error', error, stack);
      }
    }));
  }

  Future<void> _checkLatestListen() async {
    if (!_auth.isLoggedIn) return;
    try {
      final latest = await _musicService.getLatestListen();
      if (mounted && _auth.isLoggedIn && latest?.info != null) {
        setState(() {
          _latestListen = latest;
          _showContinueBanner = true;
        });
      }
    } catch (error, stack) {
      Log.e('home_screen', 'latest listen error', error, stack);
    }
  }

  Future<void> _continueListen() async {
    final latest = _latestListen;
    if (latest?.info == null) return;
    final song = SongMapper.fromTrackJson(latest!.info!);
    if (song == null) return;
    final player = context.read<PlayerProvider>();
    await player.playSong(song);
    if (!identical(player.currentSong, song)) return;
    if (latest.position > 0) {
      await player.seek(Duration(seconds: latest.position));
    }
    if (mounted) setState(() => _showContinueBanner = false);
  }

  void _playSongs(List<Song> songs,
      {int index = 0, Future<List<Song>> Function()? onEnd}) {
    if (songs.isEmpty) return;
    final player = context.read<PlayerProvider>();
    player.playSong(songs[index], playlist: songs.sublist(index));
    // 离开 FM 会清除原补队列回调，待新队列建立后再绑定推荐来源。
    player.playlistEndProvider = onEnd;
  }

  @override
  Widget build(BuildContext context) {
    final playlists = context.watch<PlaylistProvider>().topPlaylists;
    final auth = context.watch<AuthProvider>();
    final tokens = AppThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final hasContent = playlists.isNotEmpty ||
        _dailySongs.isNotEmpty ||
        _recommended.isNotEmpty ||
        _cardSongs.values.any((songs) => songs.isNotEmpty);

    return AppPageBody(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          key: const PageStorageKey('home_feed'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top + 12),
                child: AppPageHeader(
                  title: '首页',
                  subtitle: auth.isLoggedIn
                      ? '你好，${auth.user?.nickname ?? '音乐爱好者'}'
                      : '从一首喜欢的歌开始',
                  actions: [
                    IconButton.filledTonal(
                      tooltip: auth.isLoggedIn ? '个人资料' : '登录',
                      icon: const Icon(Icons.person_outline_rounded),
                      onPressed: () => Navigator.pushNamed(
                        context,
                        auth.isLoggedIn ? '/user/profile' : '/login',
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: '设置',
                      onPressed: () =>
                          Navigator.pushNamed(context, '/settings'),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.pagePadding),
                child: AppSurface(
                  color: cs.surfaceContainer,
                  onTap: widget.onSearch,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: cs.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('搜索歌曲、歌手、歌单',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ),
                      Icon(Icons.arrow_forward_rounded,
                          size: 20, color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
            if (_showContinueBanner && _latestListen != null)
              SliverToBoxAdapter(child: _buildContinueCard()),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    tokens.pagePadding, 20, tokens.pagePadding, 0),
                child: _buildDailyFeature(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    tokens.pagePadding, 12, tokens.pagePadding, 0),
                child: AppShortcutCard(
                  icon: Icons.waves_rounded,
                  title: '私人 FM',
                  subtitle: '概念同款',
                  color: cs.secondaryContainer,
                  onTap: widget.onOpenFm,
                ),
              ),
            ),
            if (_dailySongs.isNotEmpty)
              SliverToBoxAdapter(
                child: _songSection(_dailySongs, '今日为你推荐',
                    onEnd: _musicService.getDailyRecommend),
              ),
            if (playlists.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: AppSectionHeader(
                  title: '值得收藏的歌单',
                  subtitle: '把好音乐，留在身边',
                  actionLabel: '全部',
                  onAction: () =>
                      Navigator.pushNamed(context, '/recommended/playlists'),
                ),
              ),
              SliverToBoxAdapter(
                  child: DiscoverPlaylistRow(playlists: playlists)),
            ],
            if (_recommended.isNotEmpty)
              SliverToBoxAdapter(
                child: _songSection(_recommended, '新歌推荐',
                    onEnd: _musicService.getTopSongs),
              ),
            for (final id in _cardTitles.keys)
              if (_cardSongs[id]?.isNotEmpty ?? false)
                SliverToBoxAdapter(
                  child: _songSection(
                    _cardSongs[id]!,
                    _cardNames[id] ?? _cardTitles[id]!,
                    onEnd: () => id > 1000
                        ? _musicService
                            .getCardSongsYouth(id)
                            .then((card) => card.songs)
                        : _musicService
                            .getCardSongs(id)
                            .then((card) => card.songs),
                  ),
                ),
            if (_loading && !hasContent)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: AppLoadingIndicator()),
                ),
              ),
            if (!_loading && !hasContent)
              SliverToBoxAdapter(
                child: AppEmptyState(
                  icon: Icons.music_note_rounded,
                  title: '好音乐正在路上',
                  message: '暂时没有取得推荐内容，可以下拉刷新。',
                  action: FilledButton.tonal(
                    onPressed: _refresh,
                    child: const Text('重新加载'),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: PlayerBottomPadding()),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyFeature() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final available = _dailySongs.isNotEmpty;
    return AppSurface(
      color: cs.primaryContainer,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('每日推荐',
                        style: tt.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: cs.onPrimaryContainer)),
                    const SizedBox(height: 8),
                    Text(
                        available
                            ? '${_dailySongs.first.name}-${_dailySongs.first.artistDisplay}'
                            : _dailyLoading
                                ? '加载中'
                                : '暂无推荐',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium
                            ?.copyWith(color: cs.onPrimaryContainer)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (available)
                DiscoverArtwork(
                  url: _dailySongs.first.thumbnailCoverUrl,
                  size: 76,
                  radius: 26,
                )
              else
                Icon(Icons.auto_awesome_rounded, size: 48, color: cs.primary),
            ],
          ),
          const SizedBox(height: 20),
          AppPrimaryButton(
            onPressed: available
                ? () => _playSongs(_dailySongs,
                    onEnd: _musicService.getDailyRecommend)
                : _dailyLoading
                    ? null
                    : _loadDailyRecommend,
            icon: available ? Icons.play_arrow_rounded : Icons.refresh_rounded,
            label: available
                ? '播放今日推荐'
                : _dailyLoading
                    ? '正在准备推荐'
                    : '加载今日推荐',
          ),
        ],
      ),
    );
  }

  Widget _buildContinueCard() {
    final tokens = AppThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final info = _latestListen?.info;
    final song = info == null ? null : SongMapper.fromTrackJson(info);
    final songName = song?.name ?? info?['name'] as String? ?? '继续播放';
    final device = _latestListen?.deviceLabel;
    return Padding(
      padding:
          EdgeInsets.fromLTRB(tokens.pagePadding, 20, tokens.pagePadding, 0),
      child: AppSurface(
        color: cs.tertiaryContainer,
        onTap: _continueListen,
        child: Row(
          children: [
            DiscoverArtwork(url: song?.thumbnailCoverUrl, size: 52, radius: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('接着上次听', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(songName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium),
                  if (device != null && device.isNotEmpty)
                    Text(device,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            IconButton.filled(
              tooltip: '继续播放',
              onPressed: _continueListen,
              icon: const Icon(Icons.play_arrow_rounded),
            ),
            IconButton(
              tooltip: '关闭继续播放提示',
              onPressed: () => setState(() => _showContinueBanner = false),
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _songSection(List<Song> songs, String title,
      {Future<List<Song>> Function()? onEnd}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final padding = AppThemeTokens.of(context).pagePadding;
    final scaler = MediaQuery.textScalerOf(context);
    final rowHeight = (scaler.scale(tt.titleSmall?.fontSize ?? 14) *
                (tt.titleSmall?.height ?? 1.4) +
            scaler.scale(tt.bodySmall?.fontSize ?? 12) *
                (tt.bodySmall?.height ?? 1.4) +
            20)
        .ceilToDouble()
        .clamp(70.0, double.infinity);
    final colors = [
      cs.secondaryContainer,
      cs.tertiaryContainer,
      cs.primaryContainer,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: '播放',
          onAction: () => _playSongs(songs, onEnd: onEnd),
        ),
        LayoutBuilder(builder: (context, constraints) {
          final cardWidth = (constraints.maxWidth * 0.78).clamp(230.0, 340.0);
          return SizedBox(
            height: rowHeight * 3 + 20,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: padding),
              itemCount: (songs.length / 3).ceil(),
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, column) => SizedBox(
                width: cardWidth,
                child: Column(
                  children: [
                    for (var row = 0; row < 3; row++)
                      if (column * 3 + row < songs.length)
                        Padding(
                          padding: EdgeInsets.only(bottom: row == 2 ? 0 : 10),
                          child: SizedBox(
                            height: rowHeight,
                            child: Material(
                              color: colors[(column + row) % colors.length],
                              borderRadius: BorderRadius.circular(40),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => _playSongs(songs,
                                    index: column * 3 + row, onEnd: onEnd),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  child: Row(
                                    children: [
                                      DiscoverArtwork(
                                        url: songs[column * 3 + row]
                                            .thumbnailCoverUrl,
                                        size: 50,
                                        radius: 25,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              songs[column * 3 + row].name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: tt.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.w700),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              songs[column * 3 + row]
                                                  .artistDisplay,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: tt.bodySmall?.copyWith(
                                                  color: cs.onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

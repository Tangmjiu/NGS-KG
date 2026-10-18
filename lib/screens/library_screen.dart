// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import '../ui/app_ui.dart';
import '../navidrome/navidrome_provider.dart';
import '../navidrome/navidrome_screen.dart';
import '../navidrome/navidrome_login_screen.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user.dart';
import '../models/playlist.dart';
import '../models/vip_info.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import '../providers/liked_songs_provider.dart';
import '../services/music_service.dart';
import '../ui/components/playlist_card.dart';
import '../widgets/create_playlist_dialog.dart';
import '../ui/components/player_bottom_padding.dart';
import '../ui/components/song_tile.dart';
import '../providers/local_music_provider.dart';

class LibraryScreen extends StatefulWidget {
  final MusicService? musicService;

  const LibraryScreen({super.key, this.musicService});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with WidgetsBindingObserver {
  late final MusicService _musicService;
  VipInfo? _vipInfo;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _musicService = widget.musicService ?? MusicService();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  /// 公开刷新方法，供 HomeScreen 在切到该 tab 时调用
  void refresh() => _refresh();

  Future<void> _refresh({bool force = false}) async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final futures = <Future<void>>[
      _loadPlaylists(force: force),
      _loadVipInfo(),
      context.read<LocalMusicProvider>().scanMusic(),
    ];
    if (auth.isLoggedIn) {
      futures.add(context.read<LikedSongsProvider>().load(force: force));
    }
    await Future.wait(futures);
  }

  Future<void> _loadPlaylists({bool force = false}) async {
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.userId;
    if (auth.isLoggedIn && uid != null) {
      await context
          .read<PlaylistProvider>()
          .fetchUserPlaylist(uid, force: force);
    }
  }

  Future<void> _loadVipInfo() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    try {
      final info = await _musicService.getVipInfo();
      if (mounted) {
        setState(() => _vipInfo = info);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final playlistProv = context.watch<PlaylistProvider>();
    final localMusic = context.watch<LocalMusicProvider>();
    final likedSongs = context.watch<LikedSongsProvider>();
    final tokens = AppThemeTokens.of(context);

    return SafeArea(
      bottom: false,
      child: AppPageBody(
        child: RefreshIndicator(
          onRefresh: () => _refresh(force: true),
          child: CustomScrollView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(tokens.pagePadding, 16,
                    tokens.pagePadding, tokens.sectionSpacing),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppPageHeader(
                        padding: EdgeInsets.zero,
                        title: '资料库',
                        subtitle: '把喜欢的音乐留在身边',
                        actions: [
                          IconButton(
                            tooltip: '消息',
                            icon: const Icon(Icons.notifications_none_rounded),
                            onPressed: () =>
                                Navigator.pushNamed(context, '/messages'),
                          ),
                          IconButton(
                            tooltip: '设置',
                            icon: const Icon(Icons.settings_outlined),
                            onPressed: () =>
                                Navigator.pushNamed(context, '/settings'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (auth.isLoggedIn)
                        _buildUserHeader(auth)
                      else
                        _buildLoggedOutHeader(),
                      SizedBox(height: tokens.sectionSpacing),
                      _buildMenu(auth, playlistProv, localMusic, likedSongs),
                    ],
                  ),
                ),
              ),
              if (auth.isLoggedIn)
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: tokens.pagePadding),
                  sliver: _buildPlaylists(playlistProv, auth),
                ),
              const SliverToBoxAdapter(child: PlayerBottomPadding()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoggedOutHeader() {
    final cs = Theme.of(context).colorScheme;
    return AppSurface(
      color: cs.primaryContainer,
      onTap: () => Navigator.pushNamed(context, '/login'),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: cs.surface,
            child: Icon(Icons.person_outline_rounded, color: cs.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('登录音乐账号',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: cs.onPrimaryContainer)),
                const SizedBox(height: 4),
                Text('同步收藏、歌单与云盘',
                    style: TextStyle(color: cs.onPrimaryContainer)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: cs.onPrimaryContainer),
        ],
      ),
    );
  }

  Widget _buildUserHeader(AuthProvider auth) {
    final user = auth.user!;
    final cs = Theme.of(context).colorScheme;
    return AppSurface(
      onTap: () => Navigator.pushNamed(context, '/user/profile'),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: user.avatarUrl != null
                ? CachedNetworkImageProvider(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null
                ? const Icon(Icons.person_outline_rounded)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.nickname ?? '音乐爱好者',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  user.isVipActive || (_vipInfo?.isVipActive ?? false)
                      ? _vipText(user)
                      : user.userId != null
                          ? '账号 ID ${user.userId}'
                          : '查看账号资料',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }

  Widget _buildMenu(AuthProvider auth, PlaylistProvider playlistProv,
      LocalMusicProvider localMusic, LikedSongsProvider likedSongs) {
    final localCount = localMusic.songs.length;

    // 遍历用户歌单列表，查找真实的 ID 等于 2 (我喜欢) 的歌单歌曲数以确保 100% 真实同步
    int likedCount = auth.isLoggedIn ? likedSongs.likedIds.length : 0;
    if (auth.isLoggedIn) {
      for (final pl in playlistProv.userPlaylists) {
        if (pl.id == LikedSongsProvider.likedListId) {
          likedCount = pl.trackCount;
          break;
        }
      }
    }

    final items = <Widget>[
      AppShortcutCard(
        icon: Icons.favorite_rounded,
        title: '我的收藏',
        subtitle: auth.isLoggedIn ? '$likedCount 首歌曲' : '登录后同步收藏',
        color: Theme.of(context).colorScheme.primaryContainer,
        onTap: () {
          if (auth.isLoggedIn) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LikedSongsScreen()));
          } else {
            Navigator.pushNamed(context, '/login');
          }
        },
      ),
      AppShortcutCard(
        icon: Icons.folder_outlined,
        title: '本地音乐',
        subtitle: '$localCount 首歌曲',
        onTap: () => Navigator.pushNamed(context, '/local/music'),
      ),
      AppShortcutCard(
        icon: Icons.history_rounded,
        title: '听歌历史',
        subtitle: '重逢听过的旋律',
        onTap: () => Navigator.pushNamed(context, '/history'),
      ),
      AppShortcutCard(
        icon: Icons.cloud_outlined,
        title: '音乐云盘',
        subtitle: auth.isLoggedIn ? '随时聆听云端收藏' : '登录后访问云盘',
        onTap: () =>
            Navigator.pushNamed(context, auth.isLoggedIn ? '/cloud' : '/login'),
      ),
      AppShortcutCard(
        icon: Icons.dns_outlined,
        title: 'Navidrome',
        subtitle: '连接自己的音乐服务器',
        onTap: _openNavidrome,
      ),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final minWidth = 132 * MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns =
          ((constraints.maxWidth + 12) / (minWidth + 12)).floor().clamp(1, 3);
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children:
            items.map((item) => SizedBox(width: width, child: item)).toList(),
      );
    });
  }

  Future<void> _openNavidrome() async {
    final navidrome = context.read<NavidromeProvider>();
    if (!navidrome.connected) {
      await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const NavidromeLoginScreen(),
          ));
    }
    if (!mounted || !navidrome.connected) return;
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Navidrome')),
            body: const SafeArea(child: NavidromeScreen()),
          ),
        ));
  }

  String _vipText(User user) {
    if (_vipInfo?.isVipActive ?? false) {
      final label = _vipInfo!.displayName;
      final expire = _vipInfo!.expirationText;
      if (expire.isNotEmpty) return '$label · $expire';
      return label;
    }
    return user.vipLevelDisplay;
  }

  Widget _buildPlaylists(PlaylistProvider playlistProv, AuthProvider auth) {
    if (playlistProv.isLoading) {
      return const SliverToBoxAdapter(
        child: Center(child: AppLoadingIndicator()),
      );
    }

    final userId = auth.user?.userId;
    final List<Playlist> personal = [];
    final List<Playlist> collected = [];
    final List<Playlist> unknown = [];

    for (final pl in playlistProv.userPlaylists) {
      if (pl.createUserId != null &&
          userId != null &&
          pl.createUserId == userId) {
        personal.add(pl);
      } else if (pl.createUserId != null) {
        collected.add(pl);
      } else {
        unknown.add(pl);
      }
    }

    if (unknown.isNotEmpty) {
      collected.addAll(unknown);
    }

    final personalCount = personal.isEmpty ? 2 : personal.length + 1;
    final collectedCount = collected.isEmpty ? 0 : collected.length + 1;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, index) {
          if (index < personalCount) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppSectionHeader(
                  padding: EdgeInsets.zero,
                  title: '我的歌单',
                  subtitle: personal.isEmpty
                      ? '为喜欢的歌曲创建一个归处'
                      : '${personal.length} 个歌单',
                  actionLabel: '新建',
                  onAction: () => showAppDialog(
                    context: context,
                    builder: (_) => const CreatePlaylistDialog(),
                  ),
                ),
              );
            }
            if (personal.isEmpty) {
              return const AppEmptyState(
                icon: Icons.queue_music_rounded,
                title: '还没有创建歌单',
                message: '点击新建，收集属于你的音乐。',
              );
            }
            final playlist = personal[index - 1];
            return PlaylistCard(
              key: ValueKey(('personal', playlist.id)),
              playlist: playlist,
            );
          }
          final collectedIndex = index - personalCount;
          if (collectedIndex == 0) {
            return Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: AppSectionHeader(
                  padding: EdgeInsets.zero,
                  title: '收藏的歌单',
                  subtitle: '${collected.length} 个歌单'),
            );
          }
          final playlist = collected[collectedIndex - 1];
          return PlaylistCard(
            key: ValueKey(('collected', playlist.id)),
            playlist: playlist,
          );
        },
        childCount: personalCount + collectedCount,
      ),
    );
  }
}

class LikedSongsScreen extends StatefulWidget {
  const LikedSongsScreen({super.key});

  @override
  State<LikedSongsScreen> createState() => _LikedSongsScreenState();
}

class _LikedSongsScreenState extends State<LikedSongsScreen> {
  @override
  void initState() {
    super.initState();
    // 页面加载后静默拉取一次最新收藏歌曲
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<LikedSongsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final likedSongs = context.watch<LikedSongsProvider>();
    final songs = likedSongs.songs;
    final loading = !likedSongs.isLoaded && songs.isEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AppPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: '我的收藏',
                subtitle: loading ? '正在载入收藏' : '${songs.length} 首喜欢的歌曲',
                showBack: true,
              ),
              Expanded(
                child: loading
                    ? const Center(child: AppLoadingIndicator())
                    : songs.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.favorite_border_rounded,
                            title: '还没有收藏歌曲',
                            message: '收藏喜欢的歌曲，下次在这里重逢。',
                          )
                        : ListView.builder(
                            itemCount: songs.length + 1,
                            itemBuilder: (_, index) {
                              if (index == songs.length) {
                                return const PlayerBottomPadding(
                                    showLabel: false);
                              }
                              return SongTile(
                                song: songs[index],
                                onTap: (song) => context
                                    .read<PlayerProvider>()
                                    .playSong(song, playlist: songs),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../utils/app_icons.dart';
import '../utils/theme.dart';
import 'package:provider/provider.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user.dart';
import '../models/playlist.dart';
import '../models/vip_info.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import '../providers/liked_songs_provider.dart';
import '../services/music_service.dart';
import '../widgets/playlist_card.dart';
import '../widgets/create_playlist_dialog.dart';
import '../widgets/list_bottom_spacer.dart';
import '../theme/theme_assets.dart';
import '../widgets/song_tile.dart';
import '../utils/responsive.dart';
import '../widgets/song_grid_tile.dart';
import '../providers/local_music_provider.dart';
import '../routes/app_routes.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  final MusicService _musicService = MusicService();
  VipInfo? _vipInfo;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
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

  Future<void> _refresh() async {
    final auth = context.read<AuthProvider>();
    final futures = <Future<void>>[
      _loadPlaylists(),
      _loadVipInfo(),
      context.read<LocalMusicProvider>().scanMusic(),
    ];
    if (auth.isLoggedIn) {
      futures.add(context.read<LikedSongsProvider>().load());
    }
    await Future.wait(futures);
  }

  Future<void> _loadPlaylists() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.userId;
    if (auth.isLoggedIn && uid != null) {
      context.read<PlaylistProvider>().fetchUserPlaylist(uid);
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

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          if (auth.isLoggedIn)
            _buildUserHeader(auth)
          else
            _buildLoggedOutHeader(),
          const SizedBox(height: 12),
          _buildMenu(auth, playlistProv, localMusic, likedSongs),
          const SizedBox(height: 12),
          if (auth.isLoggedIn) _buildPlaylists(playlistProv, auth),
          const ListBottomSpacer(isHome: true),
        ],
      ),
    );
  }

  Widget _buildLoggedOutHeader() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return M3PressScale(
      scaleDown: 0.98,
      child: Card(
        elevation: 0,
        color: cs.surfaceContainerHigh,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/login'),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: cs.surfaceContainerHighest,
                  child: AppIcon(AppIcons.person, size: 32, color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '点击登录账号',
                        style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '登录后可同步你的云端收藏与个人歌单',
                        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                AppIcon(Symbols.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeader(AuthProvider auth) {
    final user = auth.user!;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHigh,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/user/profile'),
              child: CircleAvatar(
                radius: 32,
                backgroundImage: user.avatarUrl != null
                    ? CachedNetworkImageProvider(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? const AppIcon(AppIcons.person, size: 32)
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.nickname ?? '用户',
                      style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  if (user.userId != null) ...[
                    const SizedBox(height: 4),
                    Text('ID: ${user.userId}',
                        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                  if (user.isVipActive || (_vipInfo?.isVipActive ?? false)) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _vipInfo?.badgeType.$2 == true
                            ? const Color(0xFFFFD700)
                            : cs.primary,
                        borderRadius: AppShape.xs,
                      ),
                      child: Text(
                        _vipText(user),
                        style: tt.labelSmall?.copyWith(
                              color: _vipInfo?.badgeType.$2 == true
                                  ? Colors.black87
                                  : cs.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu(AuthProvider auth, PlaylistProvider playlistProv, LocalMusicProvider localMusic, LikedSongsProvider likedSongs) {
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

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        _buildGridItem(
          icon: Symbols.audiotrack_rounded,
          title: '本地音乐',
          value: localCount > 0 ? '$localCount' : '',
          onTap: () => Navigator.pushNamed(context, '/local/music'),
        ),
        _buildGridItem(
          icon: AppIcons.favorite,
          title: '我的收藏',
          value: auth.isLoggedIn && likedCount > 0 ? '$likedCount' : '',
          onTap: () {
            if (auth.isLoggedIn) {
                Navigator.pushNamed(context, AppRoutes.likedSongs);
            } else {
              Navigator.pushNamed(context, '/login');
            }
          },
          isLocked: !auth.isLoggedIn,
        ),
        _buildGridItem(
          icon: AppIcons.history,
          title: '听歌历史',
          value: '',
          onTap: () => Navigator.pushNamed(context, '/history'),
        ),
        _buildGridItem(
          icon: Symbols.cloud_rounded,
          title: '云盘',
          value: '',
          onTap: () {
            if (auth.isLoggedIn) {
              Navigator.pushNamed(context, '/cloud');
            } else {
              Navigator.pushNamed(context, '/login');
            }
          },
          isLocked: !auth.isLoggedIn,
        ),
        _buildGridItem(
          icon: Symbols.message_rounded,
          title: '消息',
          value: '',
          onTap: () => Navigator.pushNamed(context, '/messages'),
        ),
        _buildGridItem(
          icon: AppIcons.settings,
          title: '设置',
          value: '',
          onTap: () => Navigator.pushNamed(context, '/settings'),
        ),
      ],
    );
  }

  Widget _buildGridItem({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
    bool isLocked = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return M3PressScale(
      scaleDown: 0.96,
      child: Card(
        elevation: 0,
        color: cs.surfaceContainerHigh,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppIcon(
                      icon,
                      color: isLocked ? cs.onSurfaceVariant.withValues(alpha: 0.4) : cs.primary,
                      size: 24,
                    ),
                    if (isLocked)
                      AppIcon(Symbols.lock_rounded, color: cs.onSurfaceVariant.withValues(alpha: 0.4), size: 18)
                    else if (value.isNotEmpty)
                      Text(
                        value,
                        style: tt.labelLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                Text(
                  title,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isLocked ? cs.onSurfaceVariant.withValues(alpha: 0.6) : cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
      return const Center(child: CircularProgressIndicator());
    }

    if (playlistProv.userPlaylists.isEmpty) {
      return emptyStateWidget(ThemeAssets.emptyPlaylist, AppIcons.playlistPlay, '暂无歌单');
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (personal.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('我的歌单', style: Theme.of(context).textTheme.titleLarge),
              TextButton.icon(
                icon: const AppIcon(AppIcons.add, size: 18),
                label: const Text('新建'),
                onPressed: () => showM3Dialog(
                    context: context,
                    builder: (_) => const CreatePlaylistDialog()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...personal.asMap().entries.map((e) => M3StaggeredFadeIn(
            index: e.key,
            child: PlaylistCard(playlist: e.value),
          )),
        ],
        if (collected.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('收藏的歌单', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...collected.asMap().entries.map((e) => M3StaggeredFadeIn(
            index: e.key,
            child: PlaylistCard(playlist: e.value),
          )),
        ],
      ],
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
      context.read<LikedSongsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final likedSongs = context.watch<LikedSongsProvider>();
    final songs = likedSongs.songs;
    final loading = !likedSongs.isLoaded && songs.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : songs.isEmpty
              ? emptyStateWidget(ThemeAssets.emptyPlaylist, AppIcons.favorite, '暂无收藏')
              // ✅ 新增适配代码：平板网格封面墙 / 手机线性列表
              : context.isTablet
                  ? GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        childAspectRatio: 0.75,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                      ),
                      itemCount: songs.length,
                      itemBuilder: (_, i) => SongGridTile(
                        song: songs[i],
                        onTap: (s) => context
                            .read<PlayerProvider>()
                            .playSong(s, playlist: songs),
                      ),
                    )
                  : ListView.builder(
                      itemCount: songs.length + 1,
                      itemBuilder: (_, i) {
                        if (i == songs.length) {
                          return const ListBottomSpacer(
                              isHome: false, showText: false);
                        }
                        final song = songs[i];
                        return SongTile(
                          song: song,
                          onTap: (s) => context
                              .read<PlayerProvider>()
                              .playSong(s, playlist: songs),
                        );
                      },
                    ),
    );
  }
}

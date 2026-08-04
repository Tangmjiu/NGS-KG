import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../utils/responsive.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../routes/app_routes.dart';
import '../models/user.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../models/vip_info.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import '../providers/liked_songs_provider.dart';
import '../services/music_service.dart';
import '../widgets/playlist_card.dart';
import '../widgets/playlist_cover_card.dart';
import '../widgets/create_playlist_dialog.dart';
import '../widgets/list_bottom_spacer.dart';
import '../theme/theme_assets.dart';
import '../utils/logger.dart';
import '../widgets/song_tile.dart';
import '../providers/local_music_provider.dart';

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
    final isDesktop = Responsive.isDesktopLayout(context);

    if (isDesktop) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                children: [
                  if (auth.isLoggedIn)
                    _buildUserBanner(auth)
                  else
                    _buildLoggedOutHeader(),
                  const SizedBox(height: 20),
                  // Music You 资料库: 喜欢大卡 + 快捷卡片
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildLikedCard(auth, likedSongs),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: _buildQuickCards(auth, localMusic),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (auth.isLoggedIn)
                    _buildPlaylistsGrid(playlistProv, auth),
                  const ListBottomSpacer(isHome: true),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget body = RefreshIndicator(
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

    return body;
  }

  // ── 桌面端: 用户横幅 ──

  Widget _buildUserBanner(AuthProvider auth) {
    final user = auth.user!;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRoutes.userProfile),
              child: CircleAvatar(
                radius: 28,
                backgroundImage: user.avatarUrl != null
                    ? CachedNetworkImageProvider(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? const Icon(Icons.person, size: 28)
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(user.nickname ?? '用户',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      if (user.isVipActive ||
                          (_vipInfo?.isVipActive ?? false)) ...[
                        const SizedBox(width: 8),
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
                  if (user.userId != null) ...[
                    const SizedBox(height: 4),
                    Text('ID: ${user.userId}',
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.exit_to_app_rounded, size: 18),
              label: const Text('退出登录'),
              onPressed: () {
                auth.logout();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已退出登录')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── 桌面端: 我的收藏大卡 (Music You FavCard) ──

  Widget _buildLikedCard(AuthProvider auth, LikedSongsProvider likedSongs) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final covers = likedSongs.songs
        .take(3)
        .map((s) => s.albumCoverUrl ?? s.thumbnailCoverUrl)
        .where((u) => u != null && u.isNotEmpty)
        .toList();

    return SizedBox(
      height: 240,
      child: M3PressScale(
        scaleDown: 0.98,
        child: Card(
          elevation: 0,
          color: cs.primaryContainer.withValues(alpha: 0.4),
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: InkWell(
            onTap: () {
              if (auth.isLoggedIn) {
                Navigator.pushNamed(context, AppRoutes.likedSongs);
              } else {
                Navigator.pushNamed(context, AppRoutes.login);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_rounded,
                            color: cs.primary, size: 28),
                        const SizedBox(height: 10),
                        Text('我的收藏',
                            style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          auth.isLoggedIn
                              ? '${likedSongs.likedIds.length} 首喜欢的歌曲'
                              : '登录后同步收藏',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  // 三张随机封面
                  ...covers.take(2).map((url) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: url!.replaceAll('{size}', '240'),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 72,
                              height: 72,
                              color: cs.surfaceContainerHighest,
                              child: Icon(Icons.music_note,
                                  color: cs.onSurfaceVariant),
                            ),
                          ),
                        ),
                      )),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: Icon(Icons.arrow_forward_rounded,
                          color: cs.onSurfaceVariant, size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 桌面端: 快捷卡片 (Music You SwitchCard) ──

  Widget _buildQuickCards(AuthProvider auth, LocalMusicProvider localMusic) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final localCount = localMusic.songs.length;
    final cards = [
      (
        icon: Icons.music_note_rounded,
        title: '本地音乐',
        value: localCount > 0 ? '$localCount 首' : '',
        color: cs.tertiaryContainer,
        onColor: cs.onTertiaryContainer,
        onTap: () => Navigator.pushNamed(context, AppRoutes.localMusic),
      ),
      (
        icon: Icons.history_rounded,
        title: '听歌历史',
        value: '',
        color: cs.secondaryContainer,
        onColor: cs.onSecondaryContainer,
        onTap: () => Navigator.pushNamed(context, AppRoutes.history),
      ),
      (
        icon: Icons.cloud_rounded,
        title: '云盘',
        value: '',
        color: cs.primaryContainer,
        onColor: cs.onPrimaryContainer,
        onTap: () {
          if (auth.isLoggedIn) {
            Navigator.pushNamed(context, AppRoutes.cloud);
          } else {
            Navigator.pushNamed(context, AppRoutes.login);
          }
        },
      ),
      (
        icon: Icons.message_rounded,
        title: '消息',
        value: '',
        color: cs.surfaceContainerHighest,
        onColor: cs.onSurfaceVariant,
        onTap: () => Navigator.pushNamed(context, AppRoutes.messages),
      ),
    ];

    return SizedBox(
      height: 240,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildQuickCard(cards[0].icon, cards[0].title,
                      cards[0].value, cards[0].color, cards[0].onColor, cards[0].onTap),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickCard(cards[1].icon, cards[1].title,
                      cards[1].value, cards[1].color, cards[1].onColor, cards[1].onTap),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildQuickCard(cards[2].icon, cards[2].title,
                      cards[2].value, cards[2].color, cards[2].onColor, cards[2].onTap),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickCard(cards[3].icon, cards[3].title,
                      cards[3].value, cards[3].color, cards[3].onColor, cards[3].onTap),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCard(IconData icon, String title, String value, Color bg,
      Color fg, VoidCallback onTap) {
    final tt = Theme.of(context).textTheme;
    return M3PressScale(
      scaleDown: 0.96,
      child: Card(
        elevation: 0,
        color: bg,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: fg, size: 22),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: tt.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    if (value.isNotEmpty)
                      Text(value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelSmall?.copyWith(
                              color: fg.withValues(alpha: 0.7))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 桌面端: 歌单网格 ──

  Widget _buildPlaylistsGrid(PlaylistProvider playlistProv, AuthProvider auth) {
    if (playlistProv.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (playlistProv.userPlaylists.isEmpty) {
      return emptyStateWidget(
          ThemeAssets.emptyPlaylist, Icons.playlist_play, '暂无歌单');
    }

    final userId = auth.user?.userId;
    final List<Playlist> personal = [];
    final List<Playlist> collected = [];

    for (final pl in playlistProv.userPlaylists) {
      if (pl.createUserId != null && userId != null && pl.createUserId == userId) {
        personal.add(pl);
      } else {
        collected.add(pl);
      }
    }

    Widget grid(List<Playlist> playlists) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final cols = (constraints.maxWidth / 170).floor().clamp(2, 6);
          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.72,
            children: playlists
                .map((pl) => PlaylistCoverCard(
                      coverUrl: pl.coverUrl,
                      title: pl.name,
                      cornerRadius: 16,
                      onTap: () => Navigator.pushNamed(
                          context, AppRoutes.playlistDetail,
                          arguments: {
                            'gcId': pl.globalCollectionId ??
                                'collection_3_${pl.createUserId}_${pl.id}_0',
                            'name': pl.name,
                          }),
                      onPlay: () async {
                        try {
                          final detail = await MusicService()
                              .getPlaylistDetail(pl.globalCollectionId ??
                                  'collection_3_${pl.createUserId}_${pl.id}_0');
                          if (detail.songs.isNotEmpty && context.mounted) {
                            context.read<PlayerProvider>().playSong(
                                  detail.songs.first,
                                  playlist: detail.songs,
                                );
                          }
                        } catch (_) {}
                      },
                    ))
                .toList(),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (personal.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('我的歌单',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新建'),
                onPressed: () => showM3Dialog(
                    context: context,
                    builder: (_) => const CreatePlaylistDialog()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          grid(personal),
        ],
        if (collected.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('收藏的歌单',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          grid(collected),
        ],
      ],
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
          onTap: () => Navigator.pushNamed(context, AppRoutes.login),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: cs.surfaceContainerHighest,
                  child: Icon(Icons.person_outline_rounded,
                      size: 32, color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '点击登录账号',
                        style: tt.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '登录后可同步你的云端收藏与个人歌单',
                        style:
                            tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
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
              onTap: () => Navigator.pushNamed(context, AppRoutes.userProfile),
              child: CircleAvatar(
                radius: 32,
                backgroundImage: user.avatarUrl != null
                    ? CachedNetworkImageProvider(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? const Icon(Icons.person, size: 32)
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.nickname ?? '用户',
                      style:
                          tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  if (user.userId != null) ...[
                    const SizedBox(height: 4),
                    Text('ID: ${user.userId}',
                        style: tt.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant)),
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
          icon: Icons.audiotrack_rounded,
          title: '本地音乐',
          value: localCount > 0 ? '$localCount' : '',
          onTap: () => Navigator.pushNamed(context, AppRoutes.localMusic),
        ),
        _buildGridItem(
          icon: Icons.favorite_rounded,
          title: '我的收藏',
          value: auth.isLoggedIn && likedCount > 0 ? '$likedCount' : '',
          onTap: () {
            if (auth.isLoggedIn) {
              Navigator.pushNamed(context, AppRoutes.likedSongs);
            } else {
              Navigator.pushNamed(context, AppRoutes.login);
            }
          },
          isLocked: !auth.isLoggedIn,
        ),
        _buildGridItem(
          icon: Icons.history_rounded,
          title: '听歌历史',
          value: '',
          onTap: () => Navigator.pushNamed(context, AppRoutes.history),
        ),
        _buildGridItem(
          icon: Icons.cloud_rounded,
          title: '云盘',
          value: '',
          onTap: () {
            if (auth.isLoggedIn) {
              Navigator.pushNamed(context, AppRoutes.cloud);
            } else {
              Navigator.pushNamed(context, AppRoutes.login);
            }
          },
          isLocked: !auth.isLoggedIn,
        ),
        _buildGridItem(
          icon: Icons.message_rounded,
          title: '消息',
          value: '',
          onTap: () => Navigator.pushNamed(context, AppRoutes.messages),
        ),
        _buildGridItem(
          icon: Icons.settings_rounded,
          title: '设置',
          value: '',
          onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
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
                    Icon(
                      icon,
                      color: isLocked
                          ? cs.onSurfaceVariant.withValues(alpha: 0.4)
                          : cs.primary,
                      size: 24,
                    ),
                    if (isLocked)
                      Icon(Icons.lock_outline_rounded,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                          size: 18)
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
                    color: isLocked
                        ? cs.onSurfaceVariant.withValues(alpha: 0.6)
                        : cs.onSurface,
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
      return emptyStateWidget(
          ThemeAssets.emptyPlaylist, Icons.playlist_play, '暂无歌单');
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
                icon: const Icon(Icons.add, size: 18),
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
    final isDesktop = Responsive.isDesktopLayout(context);

    final body = loading
        ? const Center(child: CircularProgressIndicator())
        : songs.isEmpty
            ? emptyStateWidget(
                ThemeAssets.emptyPlaylist, Icons.favorite, '暂无收藏')
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
              );

    return Scaffold(
      appBar: isDesktop ? null : AppBar(title: const Text('我的收藏')),
      body: isDesktop
          ? Responsive.constrainedContent(
              context,
              maxWidth: Responsive.maxWidthList,
              child: body,
            )
          : body,
    );
  }
}

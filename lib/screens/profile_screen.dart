import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
import '../widgets/create_playlist_dialog.dart';
import '../theme/theme_assets.dart';
import '../utils/logger.dart';
import '../widgets/song_tile.dart';

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
    await Future.wait([
      _loadPlaylists(),
      _loadVipInfo(),
    ]);
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
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 880;
    return Consumer2<AuthProvider, PlaylistProvider>(
      builder: (_, auth, playlistProv, __) {
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
            if (auth.isLoggedIn) _buildUserHeader(auth),
            const SizedBox(height: 16),
            _buildMenu(auth),
            const SizedBox(height: 16),
            if (auth.isLoggedIn) _buildPlaylists(playlistProv, auth),
          ],
          ),
        );
        if (isWide) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: body,
            ),
          );
        }
        return body;
      },
    );
  }

  Widget _buildUserHeader(AuthProvider auth) {
    final user = auth.user!;
    final cs = Theme.of(context).colorScheme;
    return Card(
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
                      style: Theme.of(context).textTheme.titleLarge),
                  if (user.userId != null)
                    Text('ID: ${user.userId}',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  if (user.isVipActive || (_vipInfo?.isVipActive ?? false))
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _vipInfo?.badgeType.$2 == true
                            ? const Color(0xFFFFD700)
                            : cs.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _vipText(user),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _vipInfo?.badgeType.$2 == true
                                  ? Colors.black87
                                  : cs.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu(AuthProvider auth) {
    return Card(
      child: Column(
        children: [
          if (!auth.isLoggedIn)
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('登录'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/login'),
            ),
          ListTile(
            leading: const Icon(Icons.audiotrack),
            title: const Text('本地音乐'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/local/music'),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('听歌历史'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/history'),
          ),
          ListTile(
            leading: const Icon(Icons.message),
            title: const Text('消息'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/messages'),
          ),
          if (auth.isLoggedIn) ...[
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('我的收藏'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LikedSongsScreen()),
              ),
            ),
            // MV:
            // MV: ListTile(
            // MV:   leading: const Icon(Icons.video_library),
            // MV:   title: const Text('收藏的视频'),
            // MV:   trailing: const Icon(Icons.chevron_right),
            // MV:   onTap: () => Navigator.pushNamed(context, '/videos/favorite'),
            // MV: ),
            // MV: ListTile(
            // MV:   leading: const Icon(Icons.thumb_up),
            // MV:   title: const Text('喜欢的视频'),
            // MV:   trailing: const Icon(Icons.chevron_right),
            // MV:   onTap: () => Navigator.pushNamed(context, '/videos/liked'),
            // MV: ),
          ],
          if (auth.isLoggedIn) ...[
            ListTile(
              leading: const Icon(Icons.cloud),
              title: const Text('云盘'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/cloud'),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
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
    if (playlistProv.isLoading)
      return const Center(child: CircularProgressIndicator());

    if (playlistProv.userPlaylists.isEmpty) {
      return emptyStateWidget(ThemeAssets.emptyPlaylist, Icons.playlist_play, '暂无歌单');
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
                onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const CreatePlaylistDialog()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...personal.map((pl) => PlaylistCard(playlist: pl)),
        ],
        if (collected.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('收藏的歌单', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...collected.map((pl) => PlaylistCard(playlist: pl)),
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
  late final MusicService _musicService = context.read<MusicService>();
  List<Song> _songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final songs = await _musicService
          .getPlaylistTracksById(LikedSongsProvider.likedListId);
      if (mounted) setState(() => _songs = songs);
    } catch (e, s) {
      Log.e('profile_screen', 'error', e, s);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _songs.isEmpty
              ? emptyStateWidget(ThemeAssets.emptyPlaylist, Icons.favorite, '暂无收藏')
              : ListView.builder(
                  itemCount: _songs.length,
                  itemBuilder: (_, i) {
                    final song = _songs[i];
                    return SongTile(
                      song: song,
                      onTap: (s) => context
                          .read<PlayerProvider>()
                          .playSong(s, playlist: _songs),
                    );
                  },
                ),
    );
  }
}

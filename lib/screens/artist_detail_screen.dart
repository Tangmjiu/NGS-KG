import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../widgets/song_tile.dart';

class ArtistDetailScreen extends StatefulWidget {
  final int artistId;
  final String? artistName;

  const ArtistDetailScreen({super.key, required this.artistId, this.artistName});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen>
    with SingleTickerProviderStateMixin {
  final _musicService = MusicService();

  late TabController _tabCtrl;

  Map<String, dynamic>? _detail;
  List<Song> _songs = [];
  List<Album> _albums = [];
  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _musicService.getArtistDetail(widget.artistId),
        _musicService.getArtistAudios(widget.artistId, pageSize: 50),
        _musicService.getArtistAlbums(widget.artistId, pageSize: 50),
        _musicService.getArtistVideos(widget.artistId),
      ]);
      if (mounted) {
        setState(() {
          _detail = results[0] as Map<String, dynamic>?;
          _songs = results[1] as List<Song>;
          _albums = results[2] as List<Album>;
          _videos = results[3] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e, s) {
      Log.e('artist_detail_screen', 'load error', e, s);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    try {
      if (_isFollowing) {
        await _musicService.unfollowArtist(widget.artistId);
      } else {
        await _musicService.followArtist(widget.artistId);
      }
      if (mounted) setState(() => _isFollowing = !_isFollowing);
    } catch (e, s) {
      Log.e('artist_detail_screen', 'follow error', e, s);
    }
  }

  String? get _avatarUrl {
    final d = _detail;
    if (d == null) return null;
    // 多字段回退
    final raw = d['data'] as Map<String, dynamic>? ?? d;
    var url = raw['avatar'] as String? ??
        raw['imgurl'] as String? ??
        raw['Avatar'] as String?;
    if (url != null && url.startsWith('//')) url = 'https:$url';
    return url;
  }

  String get _artistName =>
      _detail?['data']?['name'] as String? ??
      _detail?['data']?['singer_name'] as String? ??
      widget.artistName ??
      '歌手';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (_, __) => [
                SliverAppBar(
                  expandedHeight: 240,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(_artistName,
                        style: const TextStyle(fontSize: 18)),
                    background: _buildHeaderBackground(cs, tt),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        _isFollowing ? Icons.favorite : Icons.favorite_border,
                        color: _isFollowing ? Colors.red : null,
                      ),
                      tooltip: _isFollowing ? '取消关注' : '关注',
                      onPressed: _toggleFollow,
                    ),
                  ],
                  bottom: TabBar(
                    controller: _tabCtrl,
                    tabs: [
                      const Tab(text: '热门单曲'),
                      const Tab(text: '专辑'),
                      Tab(text: 'MV (${_videos.length})'),
                    ],
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildSongsTab(cs, tt),
                  _buildAlbumsTab(cs, tt),
                  _buildVideosTab(cs, tt),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderBackground(ColorScheme cs, TextTheme tt) {
    final avatar = _avatarUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (avatar != null)
          CachedNetworkImage(
            imageUrl: avatar.replaceAll('{size}', '500'),
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) =>
                Container(color: cs.surfaceContainerHighest),
          )
        else
          Container(color: cs.surfaceContainerHighest),
        // 渐变遮罩
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.7),
              ],
            ),
          ),
        ),
        // 头像 + 名称 + 统计
        Positioned(
          left: 16,
          bottom: 56,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: avatar != null
                    ? CachedNetworkImage(
                        imageUrl: avatar.replaceAll('{size}', '240'),
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          color: cs.surfaceContainerHighest,
                          child: const Icon(Icons.person, size: 36),
                        ),
                      )
                    : Container(
                        width: 72,
                        height: 72,
                        color: cs.surfaceContainerHighest,
                        child: const Icon(Icons.person, size: 36),
                      ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_artistName,
                      style: tt.titleLarge?.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    '${_songs.length} 首单曲 · ${_albums.length} 张专辑',
                    style: tt.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── 单曲 Tab ───

  Widget _buildSongsTab(ColorScheme cs, TextTheme tt) {
    if (_songs.isEmpty) {
      return const Center(child: Text('暂无歌曲'));
    }
    return ListView.builder(
      itemCount: _songs.length,
      itemBuilder: (_, i) => SongTile(
        song: _songs[i],
        onTap: (s) => context
            .read<PlayerProvider>()
            .playSong(s, playlist: _songs),
      ),
    );
  }

  // ─── 专辑 Tab ───

  Widget _buildAlbumsTab(ColorScheme cs, TextTheme tt) {
    if (_albums.isEmpty) {
      return const Center(child: Text('暂无专辑'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _albums.length,
      itemBuilder: (_, i) {
        final album = _albums[i];
        return GestureDetector(
          onTap: () {
            if (album.id > 0) {
              Navigator.pushNamed(context, '/album/detail',
                  arguments: {'id': album.id, 'name': album.name});
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: album.coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: album.coverUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: cs.surfaceContainerHighest,
                            child: const Icon(Icons.album),
                          ),
                        )
                      : Container(
                          color: cs.surfaceContainerHighest,
                          child: const Icon(Icons.album)),
                ),
              ),
              const SizedBox(height: 6),
              Text(album.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
              if (album.songCount != null && album.songCount! > 0)
                Text('${album.songCount} 首',
                    style: tt.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        );
      },
    );
  }

  // ─── MV Tab ───

  Widget _buildVideosTab(ColorScheme cs, TextTheme tt) {
    if (_videos.isEmpty) {
      return const Center(child: Text('暂无 MV'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: _videos.length,
      itemBuilder: (_, i) {
        final mv = _videos[i];
        final name = mv['MvName'] as String? ??
            mv['name'] as String? ??
            mv['mvname'] as String? ?? '';
        final img = mv['Pic'] as String? ??
            mv['imgurl'] as String? ??
            mv['img'] as String? ?? '';
        final hash = mv['MvHash'] as String? ?? mv['hash'] as String?;
        return GestureDetector(
          onTap: () {
            if (hash != null) {
              Navigator.pushNamed(context, '/mv',
                  arguments: {'hash': hash, 'name': name});
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (img.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: img.replaceAll('{size}', '240'),
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: cs.surfaceContainerHighest,
                            child: const Icon(Icons.video_library),
                          ),
                        )
                      else
                        Container(
                          color: cs.surfaceContainerHighest,
                          child: const Icon(Icons.video_library),
                        ),
                      const Center(
                        child: Icon(Icons.play_circle_fill,
                            color: Colors.white70, size: 40),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        );
      },
    );
  }
}

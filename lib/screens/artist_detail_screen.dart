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
  // MV: List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
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
        _musicService.getArtistAudios(widget.artistId, pageSize: 500),
        _musicService.getArtistAlbums(widget.artistId, pageSize: 50),
        // MV: _musicService.getArtistVideos(widget.artistId),
      ]);
      if (mounted) {
        setState(() {
          _detail = results[0] as Map<String, dynamic>?;
          _songs = results[1] as List<Song>;
          _albums = results[2] as List<Album>;
          // MV: _videos = results[3] as List<Map<String, dynamic>>;
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
    var url = raw['sizable_avatar'] as String? ??
        raw['avatar'] as String? ??
        raw['imgurl'] as String? ??
        raw['Avatar'] as String?;
    if (url != null && url.startsWith('//')) url = 'https:$url';
    return url;
  }

  String get _artistName =>
      _detail?['data']?['author_name'] as String? ??
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
                    background: _buildHeaderBackground(cs, tt),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        _isFollowing ? Icons.favorite : Icons.favorite_border,
                        color: _isFollowing ? Theme.of(context).colorScheme.error : null,
                      ),
                      tooltip: _isFollowing ? '取消关注' : '关注',
                      onPressed: _toggleFollow,
                    ),
                  ],
                  bottom: TabBar(
                    controller: _tabCtrl,
                    tabs: [
                      const Tab(text: '单曲'),
                      const Tab(text: '专辑'),
                      // MV: Tab(text: 'MV (${_videos.length})'),
                    ],
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildSongsTab(cs, tt),
                  _buildAlbumsTab(cs, tt),
                  // MV: _buildVideosTab(cs, tt),
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
    return Column(
      children: [
        // 播放全部
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text('${_songs.length} 首单曲',
                  style: tt.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => context
                    .read<PlayerProvider>()
                    .playSong(_songs.first, playlist: _songs),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('播放全部'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _songs.length,
            itemBuilder: (_, i) => SongTile(
              song: _songs[i],
              onTap: (s) => context
                  .read<PlayerProvider>()
                  .playSong(s, playlist: _songs),
            ),
          ),
        ),
      ],
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

  // MV: Widget _buildVideosTab(ColorScheme cs, TextTheme tt) {
  // MV:   if (_videos.isEmpty) {
  // MV:     return const Center(child: Text('暂无 MV'));
  // MV:   }
  // MV:   return GridView.builder(
  // MV:     padding: const EdgeInsets.all(12),
  // MV:     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
  // MV:       crossAxisCount: 2,
  // MV:       mainAxisSpacing: 12,
  // MV:       crossAxisSpacing: 12,
  // MV:       childAspectRatio: 0.75,
  // MV:     ),
  // MV:     itemCount: _videos.length,
  // MV:     itemBuilder: (_, i) {
  // MV:       final mv = _videos[i];
  // MV:       final name = mv['MvName'] as String? ??
  // MV:           mv['name'] as String? ??
  // MV:           mv['mvname'] as String? ?? '';
  // MV:       final img = mv['Pic'] as String? ??
  // MV:           mv['imgurl'] as String? ??
  // MV:           mv['img'] as String? ?? '';
  // MV:       final hash = mv['MvHash'] as String? ?? mv['hash'] as String?;
  // MV:       return GestureDetector(
  // MV:         onTap: () {
  // MV:           if (hash != null) {
  // MV:             Navigator.pushNamed(context, '/mv',
  // MV:                 arguments: {'hash': hash, 'name': name});
  // MV:           }
  // MV:         },
  // MV:         child: Column(
  // MV:           crossAxisAlignment: CrossAxisAlignment.start,
  // MV:           children: [
  // MV:             Expanded(
  // MV:               child: ClipRRect(
  // MV:                 borderRadius: BorderRadius.circular(8),
  // MV:                 child: Stack(
  // MV:                   fit: StackFit.expand,
  // MV:                   children: [
  // MV:                     if (img.isNotEmpty)
  // MV:                       CachedNetworkImage(
  // MV:                         imageUrl: img.replaceAll('{size}', '240'),
  // MV:                         fit: BoxFit.cover,
  // MV:                         errorWidget: (_, __, ___) => Container(
  // MV:                           color: cs.surfaceContainerHighest,
  // MV:                           child: const Icon(Icons.video_library),
  // MV:                         ),
  // MV:                       )
  // MV:                     else
  // MV:                       Container(
  // MV:                         color: cs.surfaceContainerHighest,
  // MV:                         child: const Icon(Icons.video_library),
  // MV:                       ),
  // MV:                     const Center(
  // MV:                       child: Icon(Icons.play_circle_fill,
  // MV:                           color: Colors.white70, size: 40),
  // MV:                     ),
  // MV:                   ],
  // MV:                 ),
  // MV:               ),
  // MV:             ),
  // MV:             const SizedBox(height: 6),
  // MV:             Text(name,
  // MV:                 maxLines: 2,
  // MV:                 overflow: TextOverflow.ellipsis,
  // MV:                 style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
  // MV:           ],
  // MV:         ),
  // MV:       );
  // MV:     },
  // MV:   );
  // MV: }
}

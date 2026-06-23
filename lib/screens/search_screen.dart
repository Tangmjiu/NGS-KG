import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/rank_entry.dart';
import '../models/song.dart';
import '../models/song_mapper.dart';
import '../providers/player_provider.dart';
import '../services/api_client.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../utils/responsive.dart';
import '../widgets/shell_navigation_scope.dart';
import 'rank_detail_screen.dart';
import 'playlist_detail_screen.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';
import '../widgets/song_tile.dart';
import '../theme/theme_assets.dart';
import '../constants/banned_words.dart';

class SearchScreen extends StatefulWidget {
  /// Initial search query to pre-fill and optionally auto-execute.
  final String initialQuery;

  const SearchScreen({super.key, this.initialQuery = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _musicService = MusicService();

  final _tabs = ['单曲', '歌单', '专辑', '歌手', '歌词'];
  final _types = ['song', 'special', 'album', 'author', 'lyric'];

  late TabController _tabController;

  List<Song> _songs = [];
  List<Map<String, dynamic>> _playlists = [];
  List<Map<String, dynamic>> _albums = [];
  List<Map<String, dynamic>> _artists = [];
  // MV: List<Map<String, dynamic>> _mvs = [];
  List<Map<String, dynamic>> _lyrics = [];

  List<String> _suggestions = [];
  List<_HotItem> _hotSearch = [];
  List<RankEntry> _ranks = [];
  bool _isLoading = false;
  bool _isLoadingRanks = true;
  bool _showResult = false;
  bool _isBanned = false;
  String _currentKeyword = '';
  Timer? _debounce;

  /// 搜索屏蔽关键词列表
  static const _bannedKeywords = kBannedWords;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadHotSearch();
    _loadRanks();
    // Auto-execute initial query (e.g. from desktop sidebar)
    if (widget.initialQuery.isNotEmpty) {
      _searchCtrl.text = widget.initialQuery;
      // Post-frame to ensure mounted
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _doSearch(widget.initialQuery);
      });
    }
  }

  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Live search: sidebar query changed
    if (widget.initialQuery != oldWidget.initialQuery) {
      if (widget.initialQuery.isNotEmpty) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), () {
          if (mounted) {
            _searchCtrl.text = widget.initialQuery;
            _doSearch(widget.initialQuery);
          }
        });
      } else {
        _debounce?.cancel();
        if (mounted) {
          _searchCtrl.clear();
          setState(() { _showResult = false; _suggestions = []; });
        }
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (_showResult && _currentKeyword.isNotEmpty) {
      _doSearch(_currentKeyword);
    }
  }

  Future<void> _loadHotSearch() async {
    try {
      final raw = await _musicService.getHotSearch();
      if (mounted) {
        setState(() => _hotSearch = raw
            .map((e) => _HotItem(e['keyword'] as String? ?? '', e['reason'] as String? ?? ''))
            .toList());
      }
    } catch (e, s) { Log.e('search_screen', 'error', e, s); }
  }

  Future<void> _loadRanks() async {
    try {
      final ranks = await _musicService.getRankList();
      if (mounted) setState(() => _ranks = ranks);
    } catch (e, s) { Log.e('search_screen', 'error', e, s); }
    if (mounted) setState(() => _isLoadingRanks = false);
  }

  void _onSearchChanged(String keyword) {
    _debounce?.cancel();
    if (keyword.isEmpty) {
      setState(() {
        _suggestions = [];
        _showResult = false;
      });
      return;
    }
    // 屏蔽词不触发建议
    final lower = keyword.toLowerCase();
    if (_bannedKeywords.any((b) => lower.contains(b.toLowerCase()))) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        _suggestions = await _musicService.getSearchSuggest(keyword);
        if (mounted) setState(() {});
      } catch (e, s) { Log.e('search_screen', 'error', e, s); }
    });
  }

  Future<void> _doSearch(String keyword) async {
    if (keyword.isEmpty) return;
    _focusNode.unfocus();
    _currentKeyword = keyword;

    // 检查是否屏蔽关键词
    final lower = keyword.toLowerCase();
    if (_bannedKeywords.any((b) => lower.contains(b.toLowerCase()))) {
      setState(() {
        _isBanned = true;
        _isLoading = false;
        _showResult = true;
      });
      return;
    }
    setState(() => _isBanned = false);

    final type = _types[_tabController.index];
    setState(() {
      _isLoading = true;
      _showResult = true;
    });
    try {
      switch (_tabController.index) {
        case 0:
          _songs = await _musicService.search(keyword, type: type);
          break;
        case 1:
          _playlists = await _musicService.searchPlaylists(keyword);
          break;
        case 2:
          _albums = await _musicService.searchAlbums(keyword);
          break;
        case 3:
          _artists = await _musicService.searchArtists(keyword);
          break;
        // MV: case 4:
        // MV:   _mvs = await _musicService.searchMvs(keyword);
        // MV:   break;
        case 4:
          _lyrics = await _musicService.searchLyrics(keyword);
          break;
      }
    } catch (e, s) { Log.e('search_screen', 'error', e, s); }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      desktop: (_) => _buildDesktop(),
      mobile: (_) => _buildMobile(),
      tablet: (_) => _buildMobile(),
    );
  }

  Widget _buildDesktop() {
    return Column(
      children: [
        if (_showResult)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
          ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildMobile() {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          focusNode: _focusNode,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '搜索歌曲、歌单、歌手...',
            border: InputBorder.none,
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: '清除',
                    onPressed: () {
                      _searchCtrl.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
          ),
          onChanged: _onSearchChanged,
          onSubmitted: _doSearch,
        ),
        bottom: _showResult
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
              )
            : null,
      ),
      body: MediaQuery.of(context).size.width >= 880
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: _buildBody(),
              ),
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: ThemeImage(
          assetPath: ThemeAssets.loading,
          width: 120,
          height: 120,
        ),
      );
    }
    if (_isBanned) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThemeImage(
              assetPath: ThemeAssets.ban,
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 12),
            Text('当前关键词暂时无法搜索',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
          ],
        ),
      );
    }
    if (_showResult) {
      return TabBarView(
        controller: _tabController,
        children: [
          _buildSongsTab(),
          _buildPlaylistsTab(),
          _buildAlbumsTab(),
          _buildArtistsTab(),
          // MV: _buildMvsTab(),
          _buildLyricsTab(),
        ],
      );
    }

    if (_suggestions.isNotEmpty) {
      return ListView.builder(
        itemCount: _suggestions.length,
        itemBuilder: (_, i) => ListTile(
          leading: const Icon(Icons.search, size: 20),
          title: Text(_suggestions[i]),
          onTap: () {
            _searchCtrl.text = _suggestions[i];
            _doSearch(_suggestions[i]);
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_loadHotSearch(), _loadRanks()]);
      },
      child: ListView(
        children: [
          if (!_isLoadingRanks && _ranks.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('排行榜',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _ranks.length,
                itemBuilder: (_, i) {
                  final rank = _ranks[i];
                  final name = rank.name;
                  final img = rank.coverUrl ?? rank.bannerUrl ?? '';
                  return GestureDetector(
                    onTap: () {
                      if (rank.id > 0) {
                        ShellNavigationScope.navigate(
                          context,
                          routeName: '/rank/detail',
                          arguments: {'id': rank.id, 'name': name},
                          shellPageBuilder: () => RankDetailScreen(
                            rankId: rank.id,
                            rankName: name,
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 8),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: img.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: img.replaceAll('{size}', '240'),
                                    width: 72, height: 72,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      width: 72, height: 72,
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      child: const Icon(Icons.music_note),
                                    ),
                                  )
                                : Container(
                                    width: 72, height: 72,
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: const Icon(Icons.music_note),
                                  ),
                          ),
                          const SizedBox(height: 4),
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:                   Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('热搜榜',
                style: Theme.of(context).textTheme.titleLarge),
          ),
          ...List.generate(_hotSearch.length, (i) {
            final item = _hotSearch[i];
            return ListTile(
              leading: SizedBox(
                width: 28,
                child: Text('${i + 1}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: i < 3
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    )),
              ),
              title: Text(item.text),
              subtitle: item.reason.isNotEmpty && item.reason != item.text
                  ? Text(item.reason,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))
                  : null,
              onTap: () {
                _searchCtrl.text = item.text;
                _doSearch(item.text);
              },
            );
          }),
        ],
      ),
    );
  }

  /// 空结果占位图（sthiswrong.png + 文字）
  Widget _emptyResult(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ThemeImage(
            assetPath: ThemeAssets.sthiswrong,
            width: 100,
            height: 100,
          ),
          const SizedBox(height: 12),
          Text(message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
        ],
      ),
    );
  }

  Widget _buildSongsTab() {
    if (_songs.isEmpty) {
      return _emptyResult('未找到歌曲');
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

  Widget _buildPlaylistsTab() {
    if (_playlists.isEmpty) {
      return _emptyResult('未找到歌单');
    }
    return ListView.builder(
      itemCount: _playlists.length,
      itemBuilder: (_, i) {
        final p = _playlists[i];
        final name = p['specialname'] as String? ?? p['name'] as String? ?? '';
        final img = p['imgurl'] as String? ?? p['img'] as String? ?? '';
        final count = p['songcount'] as int? ?? 0;
        return ListTile(
          leading: img.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(imageUrl: img.replaceAll('{size}', '240'),
                      width: 48, height: 48, fit: BoxFit.cover),
                )
              : Container(
                  width: 48, height: 48,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.queue_music),
                ),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('$count首歌'),
          onTap: () {
            final gcId = p['global_collection_id'] as String?
                ?? p['globalCollectionId'] as String?
                ?? p['parent_global_collection_id'] as String?
                ?? p['gid'] as String?
                ?? (() {
                  final listId = p['id'] ?? p['specialid'];
                  final userId = p['list_create_userid'] ?? p['userid']
                      ?? ApiClient.userId;
                  if (listId != null && userId != null) {
                    return 'collection_3_${userId}_${listId}_0';
                  }
                  return listId?.toString();
                })();
            if (gcId != null) {
              ShellNavigationScope.navigate(
                context,
                routeName: '/playlist/detail',
                arguments: {'gcId': gcId, 'name': name},
                shellPageBuilder: () => PlaylistDetailScreen(
                  gcId: gcId,
                  playlistName: name,
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildAlbumsTab() {
    if (_albums.isEmpty) {
      return _emptyResult('未找到专辑');
    }
    return ListView.builder(
      itemCount: _albums.length,
      itemBuilder: (_, i) {
        final a = _albums[i];
        final name = a['albumname'] as String? ?? '';
        final img = a['imgurl'] as String? ?? a['img'] as String? ?? '';
        final artist = a['singer'] as String? ?? a['singername'] as String? ?? a['artist'] as String? ?? '';
        return ListTile(
          leading: img.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(imageUrl: img.replaceAll('{size}', '240'),
                      width: 48, height: 48, fit: BoxFit.cover),
                )
              : Container(
                  width: 48, height: 48,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.album),
                ),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () {
            final id = a['albumid'];
            final albumId = id is int ? id : (id is String ? int.tryParse(id) : null) ?? a['id'] as int?;
            if (albumId != null) {
              ShellNavigationScope.navigate(
                context,
                routeName: '/album/detail',
                arguments: {'id': albumId},
                shellPageBuilder: () => AlbumDetailScreen(
                  albumId: albumId,
                  albumName: null,
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildArtistsTab() {
    if (_artists.isEmpty) {
      return _emptyResult('未找到歌手');
    }
    return ListView.builder(
      itemCount: _artists.length,
      itemBuilder: (_, i) {
        final a = _artists[i];
        final name = a['AuthorName'] as String? ?? a['singername'] as String? ?? a['name'] as String? ?? '';
        final img = a['Avatar'] as String? ?? a['imgurl'] as String? ?? a['img'] as String? ?? '';
        return ListTile(
          leading: img.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: CachedNetworkImage(imageUrl: img.replaceAll('{size}', '240'),
                      width: 48, height: 48, fit: BoxFit.cover),
                )
              : Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person),
                ),
          title: Text(name),
          onTap: () {
            final id = a['AuthorId'] as int? ?? a['singermid'] as int? ?? a['id'] as int?;
            if (id != null) {
              ShellNavigationScope.navigate(
                context,
                routeName: '/artist/detail',
                arguments: {'id': id},
                shellPageBuilder: () => ArtistDetailScreen(
                  artistId: id,
                  artistName: null,
                ),
              );
            }
          },
        );
      },
    );
  }

  // MV: Widget _buildMvsTab() {
  // MV:   if (_mvs.isEmpty) {
  // MV:     return _emptyResult('未找到MV');
  // MV:   }
  // MV:   return ListView.builder(
  // MV:     itemCount: _mvs.length,
  // MV:     itemBuilder: (_, i) {
  // MV:       final m = _mvs[i];
  // MV:       final name = m['MvName'] as String? ?? m['name'] as String? ?? m['mvname'] as String? ?? '';
  // MV:       final img = m['Pic'] as String? ?? m['imgurl'] as String? ?? m['img'] as String? ?? '';
  // MV:       final artist = m['SingerName'] as String? ?? m['singername'] as String? ?? '';
  // MV:       return ListTile(
  // MV:         leading: img.isNotEmpty
  // MV:             ? ClipRRect(
  // MV:                 borderRadius: BorderRadius.circular(4),
  // MV:                 child: CachedNetworkImage(imageUrl: img.replaceAll('{size}', '240'),
  // MV:                     width: 48, height: 48, fit: BoxFit.cover),
  // MV:               )
  // MV:             : Container(
  // MV:                 width: 48, height: 48,
  // MV:                 color: Theme.of(context).colorScheme.surfaceContainerHighest,
  // MV:                 child: const Icon(Icons.video_library),
  // MV:               ),
  // MV:         title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
  // MV:         subtitle: Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis),
  // MV:         onTap: () {
  // MV:           final hash = m['MvHash'] as String? ?? m['hash'] as String?;
  // MV:           if (hash != null) {
  // MV:             Navigator.pushNamed(context, '/mv', arguments: {'hash': hash});
  // MV:           }
  // MV:         },
  // MV:       );
  // MV:     },
  // MV:   );
  // MV: }

  Widget _buildLyricsTab() {
    if (_lyrics.isEmpty) {
      return _emptyResult('未找到歌词');
    }
    return ListView.builder(
      itemCount: _lyrics.length,
      itemBuilder: (_, i) {
        final l = _lyrics[i];
        final songName = l['SongName'] as String? ?? l['songname'] as String? ?? '';
        final artist = l['SingerName'] as String? ?? l['singername'] as String? ?? '';
        final content = l['Lyric'] as String? ?? l['lyric'] as String? ?? l['content'] as String? ?? '';
        return ListTile(
          title: Text(songName, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
          isThreeLine: true,
          onTap: () {
            final song = SongMapper.fromKugouJson(l);
            if (song != null) {
              context.read<PlayerProvider>().playSong(song);
            }
          },
        );
      },
    );
  }
}

class _HotItem {
  final String text;
  final String reason;
  const _HotItem(this.text, this.reason);
}
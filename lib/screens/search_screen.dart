import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/rank_entry.dart';
import '../models/song.dart';
import '../models/song_mapper.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../widgets/song_tile.dart';
import '../theme/theme_assets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _musicService = MusicService();

  final _tabs = ['综合', '单曲', '歌单', '专辑', '歌手', 'MV', '歌词'];
  final _types = ['complex', 'song', 'special', 'album', 'author', 'mv', 'lyric'];

  late TabController _tabController;

  List<Song> _songs = [];
  List<Map<String, dynamic>> _playlists = [];
  List<Map<String, dynamic>> _albums = [];
  List<Map<String, dynamic>> _artists = [];
  List<Map<String, dynamic>> _mvs = [];
  List<Map<String, dynamic>> _lyrics = [];
  Map<String, List<dynamic>> _complexResults = {};

  List<String> _suggestions = [];
  List<_HotItem> _hotSearch = [];
  List<RankEntry> _ranks = [];
  bool _isLoading = false;
  bool _isLoadingRanks = true;
  bool _showResult = false;
  bool _isBanned = false;
  String _currentKeyword = '';
  Timer? _debounce;

  /// 搜索屏蔽关键词列表（后续可扩展或从服务器拉取）
  static const _bannedKeywords = <String>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadHotSearch();
    _loadRanks();
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
          final data = await _musicService.searchComplex(keyword);
          if (mounted) {
            setState(() {
              _complexResults = {};
              final lists = data['lists'] as Map<String, dynamic>?;
              if (lists != null) {
                for (final entry in lists.entries) {
                  final list = entry.value;
                  if (list is List && list.isNotEmpty) {
                    _complexResults[entry.key] = list;
                  }
                }
              }
            });
          }
          break;
        case 1:
          _songs = await _musicService.search(keyword, type: type);
          break;
        case 2:
          _playlists = await _musicService.searchPlaylists(keyword);
          break;
        case 3:
          _albums = await _musicService.searchAlbums(keyword);
          break;
        case 4:
          _artists = await _musicService.searchArtists(keyword);
          break;
        case 5:
          _mvs = await _musicService.searchMvs(keyword);
          break;
        case 6:
          _lyrics = await _musicService.searchLyrics(keyword);
          break;
      }
    } catch (e, s) { Log.e('search_screen', 'error', e, s); }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
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
      body: _buildBody(),
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
          _buildComplexTab(),
          _buildSongsTab(),
          _buildPlaylistsTab(),
          _buildAlbumsTab(),
          _buildArtistsTab(),
          _buildMvsTab(),
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
                        Navigator.pushNamed(context, '/rank/detail',
                            arguments: {'id': rank.id, 'name': name});
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

  static const _complexTypeLabels = {
    'song': '单曲',
    'special': '歌单',
    'album': '专辑',
    'author': '歌手',
    'mv': 'MV',
    'lyric': '歌词',
  };

  Widget _buildComplexTab() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    if (_complexResults.isEmpty) {
      return _emptyResult('未找到相关内容');
    }
    final orderedKeys = _complexResults.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: orderedKeys.length,
      itemBuilder: (_, sectionIdx) {
        final key = orderedKeys[sectionIdx];
        final items = _complexResults[key]!;
        final label = _complexTypeLabels[key] ?? key;
        final displayItems = items.length > 6 ? items.sublist(0, 6) : items;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(label, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (items.length > 6)
                    TextButton(
                      onPressed: () {
                        _tabController.animateTo(
                          _types.indexOf(key).clamp(0, _types.length - 1),
                        );
                      },
                      child: const Text('查看更多'),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: displayItems.length,
                itemBuilder: (_, i) => _buildComplexItem(displayItems[i], key, cs, tt, i, displayItems.length),
              ),
            ),
            if (sectionIdx < orderedKeys.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        );
      },
    );
  }

  Widget _buildComplexItem(dynamic item, String type, ColorScheme cs, TextTheme tt, int index, int total) {
    if (item is! Map<String, dynamic>) return const SizedBox.shrink();
    final player = context.read<PlayerProvider>();
    switch (type) {
      case 'song':
        return _buildComplexSongCard(item, cs, tt, () async {
          final song = Song.fromJson(item);
          player.playSong(song);
        });
      case 'special':
        return _buildComplexMediaCard(
          imgUrl: item['imgurl'] as String? ?? item['img'] as String? ?? '',
          title: item['specialname'] as String? ?? item['name'] as String? ?? '',
          cs: cs, tt: tt,
          icon: Icons.queue_music,
          onTap: () {
            final gcId = item['global_collection_id'] as String? ??
                item['id']?.toString() ??
                item['specialid']?.toString();
            if (gcId != null) {
              Navigator.pushNamed(context, '/playlist/detail',
                  arguments: {'gcId': gcId, 'name': item['specialname'] ?? item['name'] ?? ''});
            }
          },
        );
      case 'album':
        return _buildComplexMediaCard(
          imgUrl: item['imgurl'] as String? ?? item['img'] as String? ?? '',
          title: item['albumname'] as String? ?? item['name'] as String? ?? '',
          cs: cs, tt: tt,
          icon: Icons.album,
          onTap: () {
            final id = item['albumid'];
            final albumId = id is int ? id : (id is String ? int.tryParse(id) : null) ?? item['id'] as int?;
            if (albumId != null) {
              Navigator.pushNamed(context, '/album/detail', arguments: {'id': albumId});
            }
          },
        );
      case 'author':
        return _buildComplexMediaCard(
          imgUrl: item['Avatar'] as String? ?? item['imgurl'] as String? ?? item['img'] as String? ?? '',
          title: item['AuthorName'] as String? ?? item['singername'] as String? ?? item['name'] as String? ?? '',
          cs: cs, tt: tt,
          circular: true,
          icon: Icons.person,
          onTap: () {
            final id = item['AuthorId'] as int? ?? item['singermid'] as int? ?? item['id'] as int?;
            if (id != null) {
              Navigator.pushNamed(context, '/artist/detail', arguments: {'id': id});
            }
          },
        );
      case 'mv':
        return _buildComplexMediaCard(
          imgUrl: item['Pic'] as String? ?? item['imgurl'] as String? ?? item['img'] as String? ?? '',
          title: item['MvName'] as String? ?? item['name'] as String? ?? item['mvname'] as String? ?? '',
          cs: cs, tt: tt,
          icon: Icons.video_library,
          onTap: () {
            final hash = item['MvHash'] as String? ?? item['hash'] as String?;
            if (hash != null) {
              Navigator.pushNamed(context, '/mv', arguments: {'hash': hash});
            }
          },
        );
      case 'lyric':
        return _buildComplexLyricCard(item, cs, tt);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildComplexSongCard(Map<String, dynamic> item, ColorScheme cs, TextTheme tt, VoidCallback onTap) {
    final name = item['name'] as String? ?? '';
    final artists = (item['artists'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .join(' / ') ?? '';
    final coverUrl = (item['album'] as Map<String, dynamic>?)?['picUrl'] as String?;
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(right: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        color: cs.surfaceContainerHighest,
        child: SizedBox(
          width: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: coverUrl,
                        width: 120, height: 100,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 120, height: 100, color: cs.surfaceContainerHighest,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 120, height: 100, color: cs.surfaceContainerHighest,
                          child: Icon(Icons.music_note, color: cs.onSurfaceVariant),
                        ),
                      )
                    : Container(
                        width: 120, height: 100, color: cs.surfaceContainerHighest,
                        child: Icon(Icons.music_note, color: cs.onSurfaceVariant),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.titleSmall),
                    if (artists.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(artists, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComplexMediaCard({
    required String imgUrl,
    required String title,
    required ColorScheme cs,
    required TextTheme tt,
    IconData? icon,
    bool circular = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(right: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        color: cs.surfaceContainerHighest,
        child: SizedBox(
          width: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: imgUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imgUrl.replaceAll('{size}', '240'),
                        width: 120, height: 100,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 120, height: 100, color: cs.surfaceContainerHighest,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 120, height: 100, color: cs.surfaceContainerHighest,
                          child: Icon(icon ?? Icons.music_note, color: cs.onSurfaceVariant),
                        ),
                      )
                    : Container(
                        width: 120, height: 100, color: cs.surfaceContainerHighest,
                        child: Icon(icon ?? Icons.music_note, color: cs.onSurfaceVariant),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.titleSmall),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComplexLyricCard(Map<String, dynamic> item, ColorScheme cs, TextTheme tt) {
    final songName = item['SongName'] as String? ?? item['songname'] as String? ?? '';
    final artist = item['SingerName'] as String? ?? item['singername'] as String? ?? '';
    final content = item['Lyric'] as String? ?? item['lyric'] as String? ?? item['content'] as String? ?? '';
    return GestureDetector(
      onTap: () {
        final song = SongMapper.fromKugouJson(item);
        if (song != null) {
          context.read<PlayerProvider>().playSong(song);
        }
      },
      child: Card(
        margin: const EdgeInsets.only(right: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        color: cs.surfaceContainerHighest,
        child: SizedBox(
          width: 160,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(songName, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.titleSmall),
                const SizedBox(height: 2),
                Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
                Text(content, maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 11)),
              ],
            ),
          ),
        ),
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
            final gcId = p['global_collection_id'] as String? ??
                p['id']?.toString() ??
                p['specialid']?.toString();
            if (gcId != null) {
              Navigator.pushNamed(context, '/playlist/detail',
                  arguments: {'gcId': gcId, 'name': name});
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
              Navigator.pushNamed(context, '/album/detail', arguments: {'id': albumId});
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
              Navigator.pushNamed(context, '/artist/detail', arguments: {'id': id});
            }
          },
        );
      },
    );
  }

  Widget _buildMvsTab() {
    if (_mvs.isEmpty) {
      return _emptyResult('未找到MV');
    }
    return ListView.builder(
      itemCount: _mvs.length,
      itemBuilder: (_, i) {
        final m = _mvs[i];
        final name = m['MvName'] as String? ?? m['name'] as String? ?? m['mvname'] as String? ?? '';
        final img = m['Pic'] as String? ?? m['imgurl'] as String? ?? m['img'] as String? ?? '';
        final artist = m['SingerName'] as String? ?? m['singername'] as String? ?? '';
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
                  child: const Icon(Icons.video_library),
                ),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () {
            final hash = m['MvHash'] as String? ?? m['hash'] as String?;
            if (hash != null) {
              Navigator.pushNamed(context, '/mv', arguments: {'hash': hash});
            }
          },
        );
      },
    );
  }

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
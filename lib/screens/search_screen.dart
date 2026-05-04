import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/music_service.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../widgets/song_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _musicService = MusicService();

  List<Song> _results = [];
  List<String> _suggestions = [];
  List<_HotItem> _hotSearch = [];
  List<Map<String, dynamic>> _ranks = [];
  bool _isLoading = false;
  bool _isLoadingRanks = true;
  bool _showResult = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadHotSearch();
    _loadRanks();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadHotSearch() async {
    try {
      final raw = await _musicService.getHotSearch();
      if (mounted) {
        setState(() => _hotSearch = raw
            .map((e) => _HotItem(e['keyword'] as String? ?? '', e['reason'] as String? ?? ''))
            .toList());
      }
    } catch (_) {}
  }

  Future<void> _loadRanks() async {
    try {
      final ranks = await _musicService.getRankList();
      if (mounted) setState(() => _ranks = ranks);
    } catch (_) {}
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
      } catch (_) {}
    });
  }

  Future<void> _doSearch(String keyword) async {
    if (keyword.isEmpty) return;
    _focusNode.unfocus();
    setState(() {
      _isLoading = true;
      _showResult = true;
    });
    try {
      _results = await _musicService.search(keyword);
    } catch (_) {}
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
            hintText: '搜索歌曲、歌单...',
            border: InputBorder.none,
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
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
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_showResult) {
      return _results.isEmpty
          ? const Center(child: Text('未找到结果'))
          : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (_, i) => SongTile(
                    song: _results[i],
                    onTap: (s) => context
                        .read<PlayerProvider>()
                        .playSong(s, playlist: _results),
                  ),
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
          // 排行榜
          if (!_isLoadingRanks && _ranks.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('排行榜',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _ranks.length,
                itemBuilder: (_, i) {
                  final rank = _ranks[i];
                  final name = rank['rankname'] as String? ?? '';
                  final img = rank['imgurl'] as String? ?? rank['img_9'] as String? ?? rank['banner_9'] as String?;
                  return GestureDetector(
                    onTap: () {
                      final id = rank['rankid'] as int?;
                      if (id != null) {
                        Navigator.pushNamed(context, '/rank/detail',
                            arguments: {'id': id, 'name': name});
                      }
                    },
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 8),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: img != null
                                ? Image.network(
                                    img.replaceAll('{size}', '240'),
                                    width: 72, height: 72,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 72, height: 72,
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.music_note),
                                    ),
                                  )
                                : Container(
                                    width: 72, height: 72,
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.music_note),
                                  ),
                          ),
                          const SizedBox(height: 4),
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // 热搜榜
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('热搜榜',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                          : Colors.grey,
                    )),
              ),
              title: Text(item.text),
              subtitle: item.reason.isNotEmpty && item.reason != item.text
                  ? Text(item.reason,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]))
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
}

class _HotItem {
  final String text;
  final String reason;
  const _HotItem(this.text, this.reason);
}

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
  List<Map<String, dynamic>> _hotSearch = [];
  bool _isLoading = false;
  bool _showResult = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadHotSearch();
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
      _hotSearch = raw;
      if (mounted) setState(() {});
    } catch (_) {}
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
    setState(() => _isLoading = false);
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
            hintText: '搜索歌曲...',
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

    // 搜索建议
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

    // 热搜榜
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('热搜榜',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _hotSearch.length,
            itemBuilder: (_, i) => ListTile(
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
              title: Text(_hotSearch[i]['text'] as String? ?? ''),
              onTap: () {
                final text = _hotSearch[i]['text'] as String? ?? '';
                _searchCtrl.text = text;
                _doSearch(text);
              },
            ),
          ),
        ),
      ],
    );
  }
}

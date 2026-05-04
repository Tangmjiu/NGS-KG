import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../widgets/song_tile.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final MusicService _musicService = MusicService();
  List<Map<String, dynamic>> _ranks = [];
  List<Song>? _newSongs;
  bool _loadingRanks = true;
  bool _loadingNewSongs = true;

  @override
  void initState() {
    super.initState();
    _loadRanks();
    _loadNewSongs();
  }

  Future<void> _loadRanks() async {
    try {
      final ranks = await _musicService.getRankList();
      if (mounted) setState(() => _ranks = ranks);
    } catch (_) {}
    if (mounted) setState(() => _loadingRanks = false);
  }

  Future<void> _loadNewSongs() async {
    try {
      final songs = await _musicService.getTopSongs();
      if (mounted) setState(() => _newSongs = songs);
    } catch (_) {}
    if (mounted) setState(() => _loadingNewSongs = false);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_loadRanks(), _loadNewSongs()]);
      },
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('发现',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          _buildQuickLinks(),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('排行榜',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          if (_loadingRanks)
            const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()))
          else
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _ranks.length,
                itemBuilder: (_, i) {
                  final rank = _ranks[i];
                  final name = rank['name'] as String? ?? '';
                  final img = rank['coverImgUrl'] as String? ??
                      rank['imgUrl'] as String?;
                  return GestureDetector(
                    onTap: () => _openRank(rank),
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 8),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              img ?? '',
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 72,
                                height: 72,
                                color: Colors.grey[800],
                                child: const Icon(Icons.music_note),
                              ),
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
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('新歌速递',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          if (_loadingNewSongs)
            const Center(child: CircularProgressIndicator())
          else if (_newSongs == null || _newSongs!.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('暂无数据')),
            )
          else
            ..._newSongs!.map<Widget>((s) => SongTile(
                  song: s,
                  onTap: (song) {
                    context
                        .read<PlayerProvider>()
                        .playSong(song, playlist: _newSongs);
                  },
                )),
        ],
      ),
    );
  }

  Widget _buildQuickLinks() {
    final links = [
      ('歌手', Icons.person, '/artist/list'),
      ('电台', Icons.radio, '/fm'),
      ('曲谱', Icons.music_note, '/sheet/list'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: links
          .map((e) => Column(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pushNamed(context, e.$3),
                    icon: Icon(e.$2, size: 32),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      fixedSize: const Size(56, 56),
                    ),
                  ),
                  Text(e.$1, style: const TextStyle(fontSize: 12)),
                ],
              ))
          .toList(),
    );
  }

  void _openRank(Map<String, dynamic> rank) {
    final id = rank['id'] as int?;
    if (id == null) return;
    Navigator.pushNamed(context, '/rank/detail',
        arguments: {'id': id, 'name': rank['name'] as String?});
  }
}

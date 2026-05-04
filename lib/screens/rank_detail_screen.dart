import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../widgets/song_tile.dart';

class RankDetailScreen extends StatefulWidget {
  final int rankId;
  final String? rankName;

  const RankDetailScreen({super.key, required this.rankId, this.rankName});

  @override
  State<RankDetailScreen> createState() => _RankDetailScreenState();
}

class _RankDetailScreenState extends State<RankDetailScreen> {
  final MusicService _musicService = MusicService();
  List<Song>? _songs;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final songs = await _musicService.getRankAudios(widget.rankId);
      if (mounted) setState(() => _songs = songs);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.rankName ?? '排行榜')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _songs == null || _songs!.isEmpty
              ? const Center(child: Text('暂无歌曲'))
              : ListView.builder(
                  itemCount: _songs!.length,
                  itemBuilder: (_, i) {
                    final song = _songs![i];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text('${i + 1}'),
                      ),
                      title: Text(song.name),
                      subtitle: Text(song.artistDisplay),
                      onTap: () {
                        context
                            .read<PlayerProvider>()
                            .playSong(song, playlist: _songs);
                      },
                    );
                  },
                ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
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

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  final MusicService _musicService = MusicService();
  List<Song>? _songs;
  bool _isLoading = true;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final songs = await _musicService.getArtistAudios(widget.artistId);
      if (mounted) setState(() => _songs = songs);
    } catch (e, s) { Log.e('artist_detail_screen', 'error', e, s); }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _toggleFollow() async {
    try {
      if (_isFollowing) {
        await _musicService.unfollowArtist(widget.artistId);
      } else {
        await _musicService.followArtist(widget.artistId);
      }
      if (mounted) setState(() => _isFollowing = !_isFollowing);
    } catch (e, s) { Log.e('artist_detail_screen', 'error', e, s); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.artistName ?? '歌手详情'),
        actions: [
          IconButton(
            icon: Icon(_isFollowing ? Icons.favorite : Icons.favorite_border),
            onPressed: _toggleFollow,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _songs == null || _songs!.isEmpty
              ? const Center(child: Text('暂无歌曲'))
              : ListView.builder(
                  itemCount: _songs!.length,
                  itemBuilder: (_, i) => SongTile(
                    song: _songs![i],
                    onTap: (s) => context
                        .read<PlayerProvider>()
                        .playSong(s, playlist: _songs),
                  ),
                ),
    );
  }
}

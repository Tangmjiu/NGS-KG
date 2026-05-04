import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/song_tile.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final int? playlistId;
  final String? gcId;
  final String? playlistName;

  const PlaylistDetailScreen({
    super.key,
    this.playlistId,
    this.gcId,
    this.playlistName,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PlaylistProvider>();
      if (widget.gcId != null) {
        provider.fetchPlaylistByGcId(widget.gcId!);
      } else if (widget.playlistId != null) {
        provider.fetchPlaylistDetail(widget.playlistId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.playlistName ?? '歌单')),
      body: Consumer<PlaylistProvider>(
        builder: (_, provider, __) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final detail = provider.currentPlaylist;
          if (detail == null) {
            return const Center(child: Text('加载失败'));
          }
          if (detail.songs.isEmpty) {
            return const Center(child: Text('暂无歌曲'));
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: detail.songs.length,
            itemBuilder: (_, i) => SongTile(
              song: detail.songs[i],
              onTap: (song) {
                context
                    .read<PlayerProvider>()
                    .setPlaylist(detail.songs, startIndex: i);
              },
            ),
          );
        },
      ),
    );
  }
}

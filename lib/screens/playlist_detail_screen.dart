import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/song_tile.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String? gcId;
  final String? playlistName;

  const PlaylistDetailScreen({
    super.key,
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
      final gcId = widget.gcId;
      if (gcId != null) {
        context.read<PlaylistProvider>().fetchPlaylistDetail(gcId);
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
          final desc = detail.playlist.description;
          final hasDesc = desc != null && desc.isNotEmpty;
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: detail.songs.length + (hasDesc ? 1 : 0),
            itemBuilder: (_, i) {
              if (hasDesc && i == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(desc,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                );
              }
              final si = hasDesc ? i - 1 : i;
              final song = detail.songs[si];
              return SongTile(
                song: song,
                onTap: (s) => context
                    .read<PlayerProvider>()
                    .playSong(s, playlist: detail.songs),
              );
            },
          );
        },
      ),
    );
  }
}

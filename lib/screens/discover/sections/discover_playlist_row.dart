import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/playlist.dart';
import '../../../providers/player_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../services/music_service.dart';
import '../../../widgets/playlist_cover_card.dart';

/// 推荐歌单 — 横向滚动卡片列表 (Music You 风格 hover 播放按钮)
class DiscoverPlaylistRow extends StatelessWidget {
  final List<Playlist> playlists;

  const DiscoverPlaylistRow({super.key, required this.playlists});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: playlists.length,
        itemBuilder: (_, i) {
          final pl = playlists[i];
          final gcId = pl.globalCollectionId ??
              'collection_3_${pl.createUserId}_${pl.id}_0';
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: PlaylistCoverCard(
              coverUrl: pl.coverUrl,
              title: pl.name,
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.playlistDetail,
                    arguments: {'gcId': gcId, 'name': pl.name});
              },
              onPlay: () => _playPlaylist(context, gcId),
            ),
          );
        },
      ),
    );
  }

  Future<void> _playPlaylist(BuildContext context, String gcId) async {
    try {
      final detail = await MusicService().getPlaylistDetail(gcId);
      if (detail.songs.isEmpty || !context.mounted) return;
      final player = context.read<PlayerProvider>();
      player.playSong(detail.songs.first, playlist: detail.songs);
    } catch (_) {}
  }
}

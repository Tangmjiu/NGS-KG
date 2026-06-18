import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/playlist.dart';
import '../services/music_service.dart';

/// 推荐歌单更多页面 — 分页网格展示所有推荐歌单
class RecommendedPlaylistsScreen extends StatefulWidget {
  const RecommendedPlaylistsScreen({super.key});

  @override
  State<RecommendedPlaylistsScreen> createState() =>
      _RecommendedPlaylistsScreenState();
}

class _RecommendedPlaylistsScreenState
    extends State<RecommendedPlaylistsScreen> {
  late final MusicService _musicService = context.read<MusicService>();
  final List<Playlist> _playlists = [];
  bool _loading = true;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 30;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    if (!_hasMore) return;
    setState(() => _loading = true);
    try {
      final list = await _musicService.getTopPlaylists(
        limit: _limit,
        offset: _offset,
      );
      if (mounted) {
        setState(() {
          _playlists.addAll(list);
          _offset += list.length;
          _hasMore = list.length >= _limit;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _playlists.clear();
      _offset = 0;
      _hasMore = true;
    });
    await _loadPlaylists();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('推荐歌单', style: tt.titleMedium),
      ),
      body: _playlists.isEmpty && _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _onRefresh,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollEndNotification &&
                      notification.metrics.pixels >=
                          notification.metrics.maxScrollExtent - 200) {
                    _loadPlaylists();
                  }
                  return false;
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount =
                        (constraints.maxWidth / 160).floor().clamp(2, 6);
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _playlists.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _playlists.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        final p = _playlists[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/playlist/detail',
                              arguments: {
                                'gcId': p.globalCollectionId ??
                                    'collection_3_${p.createUserId}_${p.id}_0',
                                'name': p.name,
                              },
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: (p.coverUrl != null &&
                                        p.coverUrl!.isNotEmpty)
                                    ? CachedNetworkImage(
                                        imageUrl: p.coverUrl!,
                                        width: double.infinity,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(
                                          width: double.infinity,
                                          height: 100,
                                          color: cs.surfaceContainerHighest,
                                          child: const Icon(
                                              Icons.playlist_play),
                                        ),
                                      )
                                    : Container(
                                        width: double.infinity,
                                        height: 100,
                                        color: cs.surfaceContainerHighest,
                                        child: const Icon(
                                            Icons.playlist_play),
                                      ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodySmall,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
    );
  }
}

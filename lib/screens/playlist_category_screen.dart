import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/staggered_fade_slide.dart';
import '../models/playlist.dart';
import '../services/music_service.dart';
import '../utils/responsive.dart';
import '../widgets/desktop_route_wrapper.dart';
import '../widgets/shell_navigation_scope.dart';
import 'playlist_detail_screen.dart';

class PlaylistCategoryScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const PlaylistCategoryScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<PlaylistCategoryScreen> createState() => _PlaylistCategoryScreenState();
}

class _PlaylistCategoryScreenState extends State<PlaylistCategoryScreen> {
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
    try {
      final list = await _musicService.getTopPlaylists(
        categoryId: widget.categoryId,
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

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      mobile: (_) => Scaffold(
        appBar: AppBar(title: Text(widget.categoryName)),
        body: _loading && _playlists.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount =
                      (constraints.maxWidth / 160).floor().clamp(2, 6);
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _playlists.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) =>
                        _buildMobileItem(context, index),
                  );
                },
              ),
      ),
      desktop: (_) => DesktopRouteWrapper(
        title: widget.categoryName,
        child: _loading && _playlists.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 0.77,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _playlists.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) =>
                    _buildDesktopItem(context, index),
              ),
      ),
    );
  }

  void _openPlaylist(Playlist p) {
    ShellNavigationScope.navigate(
      context,
      routeName: '/playlist/detail',
      arguments: {
        'gcId': p.globalCollectionId ??
            'collection_3_${p.createUserId}_${p.id}_0',
        'name': p.name,
      },
      shellPageBuilder: () => PlaylistDetailScreen(
        gcId: p.globalCollectionId ??
            'collection_3_${p.createUserId}_${p.id}_0',
        playlistName: p.name,
      ),
    );
  }

  Widget _buildMobileItem(BuildContext context, int index) {
    if (index >= _playlists.length) {
      _loadPlaylists();
      return const Center(child: CircularProgressIndicator());
    }
    final p = _playlists[index];
    return StaggeredFadeSlide(
      index: index,
      slideOffset: 8,
      staggerMs: 20,
      child: GestureDetector(
        onTap: () => _openPlaylist(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: (p.coverUrl != null && p.coverUrl!.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: p.coverUrl!,
                    width: double.infinity,
                    height: 100,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: double.infinity,
                      height: 100,
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: const Icon(Icons.playlist_play),
                    ),
                  )
                : Container(
                    width: double.infinity,
                    height: 100,
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: const Icon(Icons.playlist_play),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            p.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ));
  }

  Widget _buildDesktopItem(BuildContext context, int index) {
    if (index >= _playlists.length) {
      _loadPlaylists();
      return const Center(child: CircularProgressIndicator());
    }
    final p = _playlists[index];
    return StaggeredFadeSlide(
      index: index,
      slideOffset: 8,
      staggerMs: 20,
      child: GestureDetector(
        onTap: () => _openPlaylist(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: (p.coverUrl != null && p.coverUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: p.coverUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Icon(Icons.playlist_play),
                      ),
                    )
                  : Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: const Icon(Icons.playlist_play),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            p.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 2),
          Text(
            '${p.trackCount}首歌曲',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    ));
  }
}

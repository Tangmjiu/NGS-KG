import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/playlist.dart';
import '../models/playlist_tag.dart';
import '../utils/logger.dart';
import '../services/music_service.dart';

class CategorySelectionScreen extends StatefulWidget {
  const CategorySelectionScreen({super.key});

  @override
  State<CategorySelectionScreen> createState() => _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen> {
  final _musicService = MusicService();
  List<PlaylistTag> _tags = [];
  bool _loading = true;
  int? _selectedTagIndex;
  List<Playlist> _playlists = [];
  bool _loadingPlaylists = false;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    try {
      final tags = await _musicService.getPlaylistTags();
      if (mounted) {
        setState(() {
          _tags = tags;
          _loading = false;
        });
      }
    } catch (e, s) { Log.e('category_selection_screen', 'error', e, s);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPlaylists(int categoryId) async {
    setState(() {
      _loadingPlaylists = true;
      _playlists = [];
    });
    try {
      final list = await _musicService.getTopPlaylists(
        categoryId: categoryId,
        limit: 50,
      );
      if (mounted) {
        setState(() {
          _playlists = list;
          _loadingPlaylists = false;
        });
      }
    } catch (e, s) { Log.e('category_selection_screen', 'error', e, s);
      if (mounted) setState(() => _loadingPlaylists = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('歌单分类')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Left: category list
                SizedBox(
                  width: 120,
                  child: ListView.builder(
                    itemCount: _tags.length,
                    itemBuilder: (_, i) {
                      final tag = _tags[i];
                      final isSelected = _selectedTagIndex == i;
                      return Material(
                        color: isSelected ? cs.primaryContainer : cs.surface,
                        child: InkWell(
                          onTap: () {
                            setState(() => _selectedTagIndex = i);
                            if (tag.id > 0) _loadPlaylists(tag.id);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            child: Text(
                              tag.name,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? cs.primary : cs.onSurface,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Right: playlists or subcategories
                Expanded(
                  child: _selectedTagIndex == null
                      ? Center(
                          child: Text('请选择分类', style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
                        )
                      : _loadingPlaylists
                          ? const Center(child: CircularProgressIndicator())
                          : _playlists.isEmpty
                              ? Center(
                                  child: Text('暂无歌单', style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
                                )
                              : _buildPlaylistGrid(cs),
                ),
              ],
            ),
    );
  }

  Widget _buildPlaylistGrid(ColorScheme cs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 150).floor().clamp(2, 4);
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _playlists.length,
          itemBuilder: (_, i) {
            final p = _playlists[i];
            return GestureDetector(
              onTap: () {
                final gcId = p.globalCollectionId ?? 'collection_3_${p.createUserId}_${p.id}_0';
                Navigator.pushNamed(
                  context,
                  '/playlist/detail',
                  arguments: {'gcId': gcId, 'name': p.name},
                );
              },
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
                              color: cs.surfaceContainerHighest,
                              child: const Icon(Icons.playlist_play),
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            height: 100,
                            color: cs.surfaceContainerHighest,
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
            );
          },
        );
      },
    );
  }
}

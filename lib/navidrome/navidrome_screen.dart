import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../widgets/local_cover_art.dart';
import 'navidrome_provider.dart';
import 'navidrome_models.dart';

/// A 3-level browse screen for Navidrome music:
/// artists → albums → songs, with search and breadcrumb navigation.
class NavidromeScreen extends StatefulWidget {
  const NavidromeScreen({super.key});

  @override
  State<NavidromeScreen> createState() => _NavidromeScreenState();
}

class _NavidromeScreenState extends State<NavidromeScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NavidromeProvider>(
      builder: (context, prov, _) {
        return Column(
          children: [
            // Search bar
            _buildSearchBar(prov),
            // Breadcrumb
            if (!_isSearching) _buildBreadcrumb(prov),
            // Loading indicator
            if (prov.isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_isSearching)
              Expanded(child: _buildSearchResults(prov))
            else
              Expanded(child: _buildCurrentLevel(prov)),
          ],
        );
      },
    );
  }

  // ── Search Bar ──

  Widget _buildSearchBar(NavidromeProvider prov) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: '搜索 Navidrome 音乐...',
          prefixIcon:
              Icon(Icons.search, size: 20, color: cs.onSurfaceVariant),
          suffixIcon: _isSearching
              ? IconButton(
                  icon:
                      Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _isSearching = false);
                    prov.clearSearch();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: cs.surfaceContainerHighest,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          isDense: true,
        ),
        style: Theme.of(context).textTheme.bodySmall,
        onChanged: (q) {
          if (q.isNotEmpty) {
            setState(() => _isSearching = true);
            prov.search(q);
          } else {
            setState(() => _isSearching = false);
            prov.clearSearch();
          }
        },
      ),
    );
  }

  // ── Breadcrumb ──

  Widget _buildBreadcrumb(NavidromeProvider prov) {
    final cs = Theme.of(context).colorScheme;
    final items = <Widget>[];

    items.add(
      _breadcrumbItem(
        '歌手',
        prov.currentLevel == BrowseLevel.artists,
        prov.currentLevel != BrowseLevel.artists ? () => prov.goBack() : null,
      ),
    );

    if (prov.selectedArtistName != null) {
      items.add(Text(' / ', style: TextStyle(color: cs.onSurfaceVariant)));
      items.add(
        _breadcrumbItem(
          prov.selectedArtistName!,
          prov.currentLevel == BrowseLevel.albums,
          prov.currentLevel == BrowseLevel.songs
              ? () => prov.goBack()
              : null,
        ),
      );
    }

    if (prov.selectedAlbumName != null &&
        prov.currentLevel == BrowseLevel.songs) {
      items.add(Text(' / ', style: TextStyle(color: cs.onSurfaceVariant)));
      items.add(_breadcrumbItem(prov.selectedAlbumName!, true, null));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: items),
    );
  }

  Widget _breadcrumbItem(
      String label, bool isActive, VoidCallback? onTap) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          color: isActive ? cs.primary : cs.onSurface,
          decoration: onTap != null ? TextDecoration.underline : null,
          decorationColor: cs.onSurfaceVariant,
        ),
      ),
    );
  }

  // ── Current level routing ──

  Widget _buildCurrentLevel(NavidromeProvider prov) {
    switch (prov.currentLevel) {
      case BrowseLevel.artists:
        return _buildArtistList(prov);
      case BrowseLevel.albums:
        return _buildAlbumGrid(prov);
      case BrowseLevel.songs:
        return _buildSongList(prov);
    }
  }

  // ── Artists (ListView) ──

  Widget _buildArtistList(NavidromeProvider prov) {
    if (prov.artists.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              '暂无歌手',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: prov.artists.length,
      itemBuilder: (_, i) {
        final artist = prov.artists[i];
        return _ArtistTile(
          artist: artist,
          onTap: () => prov.selectArtist(artist.id, artist.name),
          getCoverUrl: (id) => prov.getCoverArtUrl(id),
        );
      },
    );
  }

  // ── Albums (GridView) ──

  Widget _buildAlbumGrid(NavidromeProvider prov) {
    if (prov.albums.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.album_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              '暂无专辑',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: prov.albums.length,
      itemBuilder: (_, i) => _AlbumCard(
        album: prov.albums[i],
        onTap: () =>
            prov.selectAlbum(prov.albums[i].id, prov.albums[i].name),
        getCoverUrl: (id) => prov.getCoverArtUrl(id),
      ),
    );
  }

  // ── Songs (ListView with SongTile style) ──

  Widget _buildSongList(NavidromeProvider prov) {
    final songs = prov.toSongList(prov.songs);
    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_off,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              '暂无歌曲',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    return _buildSongListView(songs);
  }

  Widget _buildSongListView(List<Song> songs) {
    final cs = Theme.of(context).colorScheme;
    final currentSongId = context.watch<PlayerProvider>().currentSong?.id;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: songs.length,
      itemBuilder: (_, i) {
        final song = songs[i];
        final isCurrent = song.id == currentSongId;
        return ListTile(
          leading: LocalCoverArt(
            url: song.albumCoverUrl,
            size: 40,
            borderRadius: 4,
          ),
          title: Text(
            song.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              color: isCurrent ? cs.primary : null,
            ),
          ),
          subtitle: Text(
            song.artistDisplay,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          trailing: isCurrent
              ? Icon(Icons.volume_up, size: 18, color: cs.primary)
              : null,
          onTap: () {
            context.read<PlayerProvider>().playSong(song, playlist: songs);
          },
        );
      },
    );
  }

  // ── Search Results ──

  Widget _buildSearchResults(NavidromeProvider prov) {
    if (prov.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (prov.searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              '未找到匹配结果',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    final songs = prov.toSongList(prov.searchResults);
    return _buildSongListView(songs);
  }
}

// ── Artist Tile ──

class _ArtistTile extends StatelessWidget {
  final SubsonicArtist artist;
  final VoidCallback onTap;
  final String? Function(String?) getCoverUrl;

  const _ArtistTile({
    required this.artist,
    required this.onTap,
    required this.getCoverUrl,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: LocalCoverArt(
        url: getCoverUrl(artist.coverArt),
        size: 48,
        borderRadius: 24,
      ),
      title: Text(artist.name,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${artist.albumCount} 张专辑 · ${artist.songCount} 首歌曲',
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      trailing:
          Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

// ── Album Card ──

class _AlbumCard extends StatelessWidget {
  final SubsonicAlbum album;
  final VoidCallback onTap;
  final String? Function(String?) getCoverUrl;

  const _AlbumCard({
    required this.album,
    required this.onTap,
    required this.getCoverUrl,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: LocalCoverArt(
                url: getCoverUrl(album.coverArt),
                size: null, // fill available
                fit: BoxFit.cover,
                borderRadius: 0,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  if (album.year > 0)
                    Text('${album.year}',
                        style: tt.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  if (album.year > 0 && album.songCount > 0)
                    Text(' · ',
                        style: tt.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  if (album.songCount > 0)
                    Text('${album.songCount} 首',
                        style: tt.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import '../theme/app_theme_tokens.dart';
import '../ui/components/app_components.dart';
import '../ui/components/app_empty_state.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../ui/components/cover_art.dart';
import 'navidrome_provider.dart';
import 'navidrome_models.dart';
import '../ui/components/player_bottom_padding.dart';

/// 私人音乐库的歌手、专辑、歌曲三级浏览与搜索。
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
  Widget build(BuildContext context) => AppPageBody(
        child: Consumer<NavidromeProvider>(
          builder: (context, prov, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchBar(prov),
              if (!_isSearching) _buildBreadcrumb(prov),
              if (prov.error != null)
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: AppThemeTokens.of(context).pagePadding),
                  child: AppSurface(
                    color: Theme.of(context).colorScheme.errorContainer,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(children: [
                      Expanded(
                          child: Text(prov.error!,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer))),
                      TextButton(
                          onPressed: () => _retryBrowse(prov),
                          child: const Text('重试')),
                    ]),
                  ),
                ),
              Expanded(
                child: prov.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _isSearching
                        ? _buildSearchResults(prov)
                        : _buildCurrentLevel(prov),
              ),
            ],
          ),
        ),
      );

  Widget _buildSearchBar(NavidromeProvider prov) {
    final cs = Theme.of(context).colorScheme;
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding:
          EdgeInsets.fromLTRB(tokens.pagePadding, 8, tokens.pagePadding, 12),
      child: TextField(
        controller: _searchCtrl,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: '搜索私人音乐库',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _isSearching
              ? IconButton(
                  tooltip: '清空搜索',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _isSearching = false);
                    prov.clearSearch();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(tokens.controlRadius),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(tokens.controlRadius),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: cs.surfaceContainerHigh,
        ),
        onChanged: (query) {
          setState(() => _isSearching = query.trim().isNotEmpty);
          if (_isSearching) {
            prov.search(query);
          } else {
            prov.clearSearch();
          }
        },
      ),
    );
  }

  Widget _buildBreadcrumb(NavidromeProvider prov) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding:
          EdgeInsets.fromLTRB(tokens.pagePadding, 0, tokens.pagePadding, 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _breadcrumbItem(
                  '全部歌手',
                  prov.currentLevel == BrowseLevel.artists,
                  prov.currentLevel == BrowseLevel.artists
                      ? null
                      : () {
                          if (prov.currentLevel == BrowseLevel.songs) {
                            prov.goBack();
                          }
                          if (prov.currentLevel == BrowseLevel.albums) {
                            prov.goBack();
                          }
                        },
                ),
                if (prov.currentLevel != BrowseLevel.artists &&
                    prov.selectedArtistName != null) ...[
                  const Icon(Icons.chevron_right_rounded, size: 18),
                  _breadcrumbItem(
                    prov.selectedArtistName!,
                    prov.currentLevel == BrowseLevel.albums,
                    prov.currentLevel == BrowseLevel.songs ? prov.goBack : null,
                  ),
                ],
                if (prov.currentLevel == BrowseLevel.songs &&
                    prov.selectedAlbumName != null) ...[
                  const Icon(Icons.chevron_right_rounded, size: 18),
                  _breadcrumbItem(prov.selectedAlbumName!, true, null),
                ],
              ]),
            ),
          ),
          IconButton(
            tooltip: '刷新音乐库',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: prov.isLoading
                ? null
                : () {
                    if (prov.currentLevel == BrowseLevel.songs) prov.goBack();
                    if (prov.currentLevel == BrowseLevel.albums) prov.goBack();
                    prov.loadArtists();
                  },
          ),
        ],
      ),
    );
  }

  Widget _breadcrumbItem(String label, bool isActive, VoidCallback? onTap) {
    final cs = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: cs.onSurfaceVariant,
        disabledForegroundColor: isActive ? cs.primary : cs.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      child: Text(label,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          )),
    );
  }

  void _retryBrowse(NavidromeProvider prov) {
    if (_isSearching) {
      prov.search(_searchCtrl.text);
    } else if (prov.selectedAlbumId != null && prov.selectedAlbumName != null) {
      prov.selectAlbum(prov.selectedAlbumId!, prov.selectedAlbumName!);
    } else if (prov.selectedArtistId != null &&
        prov.selectedArtistName != null) {
      prov.selectArtist(prov.selectedArtistId!, prov.selectedArtistName!);
    } else {
      prov.loadArtists();
    }
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
      return const AppEmptyState(
        icon: Icons.people_outline_rounded,
        title: '音乐库还没有歌手',
        message: '同步音乐到服务器后，即可在这里浏览。',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(
          horizontal: AppThemeTokens.of(context).pagePadding),
      itemCount: prov.artists.length + 1,
      itemBuilder: (_, i) {
        if (i == prov.artists.length) {
          return const PlayerBottomPadding(showLabel: false);
        }
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
      return const AppEmptyState(
        icon: Icons.album_outlined,
        title: '这位歌手还没有专辑',
        message: '可以返回歌手列表，继续寻找想听的音乐。',
      );
    }

    return Selector<PlayerProvider, bool>(
      selector: (_, player) =>
          player.currentSong != null && !player.isPlayerScreenVisible,
      builder: (context, showMini, _) => LayoutBuilder(
        builder: (context, constraints) {
          final inset = AppThemeTokens.of(context).pagePadding;
          final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final available = constraints.maxWidth - 2 * inset;
          final columns = textScale > 1.6 || available < 260
              ? 1
              : (available / 180).floor().clamp(2, 5).toInt();
          final cardWidth = (available - (columns - 1) * 16) / columns;
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(inset, 8, inset, showMini ? 104 : 32),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: cardWidth + 76 * textScale,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: prov.albums.length,
            itemBuilder: (_, index) => _AlbumCard(
              album: prov.albums[index],
              onTap: () => prov.selectAlbum(
                  prov.albums[index].id, prov.albums[index].name),
              getCoverUrl: prov.getCoverArtUrl,
            ),
          );
        },
      ),
    );
  }

  // ── Songs (ListView with SongTile style) ──

  Widget _buildSongList(NavidromeProvider prov) {
    final songs = prov.playbackSongs;
    if (songs.isEmpty) {
      return const AppEmptyState(
        icon: Icons.music_note_outlined,
        title: '专辑中暂无歌曲',
        message: '可以返回专辑列表，继续浏览音乐库。',
      );
    }
    return _buildSongListView(songs);
  }

  Widget _buildSongListView(List<Song> songs) {
    return Selector<PlayerProvider, int?>(
      selector: (_, player) => player.currentSong?.id,
      builder: (context, currentSongId, _) =>
          _buildSongListItems(context, songs, currentSongId),
    );
  }

  Widget _buildSongListItems(
      BuildContext context, List<Song> songs, int? currentSongId) {
    final cs = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: EdgeInsets.symmetric(
          horizontal: AppThemeTokens.of(context).pagePadding, vertical: 4),
      itemCount: songs.length + 1,
      itemBuilder: (_, i) {
        if (i == songs.length) {
          return const PlayerBottomPadding(showLabel: false);
        }
        final song = songs[i];
        final isCurrent = song.id == currentSongId;
        return ListTile(
          leading: CoverArt(
            url: song.albumCoverUrl,
            size: 48,
            borderRadius: AppThemeTokens.of(context).controlRadius,
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
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
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
      return const AppEmptyState(
        icon: Icons.search_off_rounded,
        title: '未找到匹配的歌曲',
        message: '试试其他歌曲或歌手名称。',
      );
    }
    final songs = prov.searchPlaybackSongs;
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
      leading: CoverArt(
        url: getCoverUrl(artist.coverArt),
        size: 48,
        borderRadius: 24,
      ),
      title: Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${artist.albumCount} 张专辑 · ${artist.songCount} 首歌曲',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
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
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(AppThemeTokens.of(context).cardRadius)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                  builder: (context, constraints) => CoverArt(
                        url: getCoverUrl(album.coverArt),
                        size: constraints.maxWidth,
                        fit: BoxFit.cover,
                        borderRadius: 0,
                      )),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Text(album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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

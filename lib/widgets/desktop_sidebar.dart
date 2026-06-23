import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../providers/playlist_provider.dart';
import '../widgets/create_playlist_dialog.dart';

/// Navigation item descriptor for the desktop sidebar.
class _NavItem {
  final IconData icon;
  final String label;
  final String id;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.id,
  });
}

/// Left navigation sidebar for the desktop layout.
///
/// Includes a search field, library navigation items, and a scrollable
/// list of user playlists with a "+" create button.
class DesktopSidebar extends StatefulWidget {
  final String? activeNavId;
  final int? activePlaylistId;
  final ValueChanged<String> onNavSelected;
  final ValueChanged<Playlist> onPlaylistSelected;
  final ValueChanged<String> onSearchChanged;
  final String searchQuery;

  static const double sidebarWidth = 240.0;

  const DesktopSidebar({
    super.key,
    this.activeNavId,
    this.activePlaylistId,
    required this.onNavSelected,
    required this.onPlaylistSelected,
    required this.onSearchChanged,
    this.searchQuery = '',
  });

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.home_outlined, label: '首页', id: 'home'),
    _NavItem(icon: Icons.explore_outlined, label: '发现', id: 'discover'),
    _NavItem(icon: Icons.person_outline, label: '我的', id: 'profile'),
    _NavItem(icon: Icons.folder_outlined, label: '本地', id: 'local'),
    _NavItem(icon: Icons.trending_up, label: '听歌排行', id: 'ranking'),
    _NavItem(icon: Icons.history, label: '最近播放', id: 'recent'),
  ];

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(DesktopSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync external query changes (e.g. cleared by nav) without losing cursor
    if (widget.searchQuery != _searchCtrl.text) {
      _searchCtrl.text = widget.searchQuery;
      _searchCtrl.selection = TextSelection.collapsed(offset: widget.searchQuery.length);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: DesktopSidebar.sidebarWidth,
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        border: Border(
          right: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // ── Search field ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: SizedBox(
              height: 36,
              child: TextField(
                onChanged: widget.onSearchChanged,
                controller: _searchCtrl,
                style: tt.bodySmall?.copyWith(color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: '搜索',
                  hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  prefixIcon: Icon(Icons.search, size: 18, color: cs.onSurfaceVariant),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),

          // ── Navigation items ──
          ...DesktopSidebar._navItems.map((item) => _SidebarNavTile(
                icon: item.icon,
                label: item.label,
                isSelected: widget.activeNavId == item.id,
                onTap: () => widget.onNavSelected(item.id),
              )),

          // ── Divider ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Divider(height: 1, color: cs.outlineVariant),
          ),

          // ── Playlists header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Text('个人歌单', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                const Spacer(),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    icon: Icon(Icons.add, size: 18, color: cs.onSurfaceVariant),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const CreatePlaylistDialog(),
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: '新建歌单',
                  ),
                ),
              ],
            ),
          ),

          // ── Playlist list ──
          Expanded(
            child: Consumer<PlaylistProvider>(
              builder: (context, plProvider, _) {
                final playlists = plProvider.userPlaylists;

                if (playlists.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '暂无歌单\n点击 "+" 创建',
                        textAlign: TextAlign.center,
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: playlists.length,
                  itemBuilder: (_, i) {
                    final pl = playlists[i];
                    final isSelected = pl.id == widget.activePlaylistId;
                    return _PlaylistSidebarTile(
                      playlist: pl,
                      isSelected: isSelected,
                      onTap: () => widget.onPlaylistSelected(pl),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Single navigation tile in the sidebar.
class _SidebarNavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarNavTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: isSelected ? cs.secondaryContainer.withValues(alpha: 0.4) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? cs.primary : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single playlist tile in the sidebar.
class _PlaylistSidebarTile extends StatelessWidget {
  final Playlist playlist;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlaylistSidebarTile({
    required this.playlist,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: isSelected ? cs.secondaryContainer.withValues(alpha: 0.4) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                Icons.playlist_play,
                size: 18,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? cs.primary : cs.onSurface,
                  ),
                ),
              ),
              if (playlist.trackCount > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '${playlist.trackCount}',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

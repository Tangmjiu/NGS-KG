import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/responsive.dart';
import '../providers/player_provider.dart';

class TabletScaffold extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final List<Widget> pages;
  final List<BottomNavigationBarItem> tabs;

  const TabletScaffold({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
    required this.pages,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    if (!Responsive.isTabletLandscape(context)) {
      return _phoneLayout(context);
    }
    return _tabletLayout(context);
  }

  Widget _phoneBottomNav() {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTabChanged,
      items: tabs,
    );
  }

  Widget _phoneLayout(BuildContext context) {
    final page = pages[currentIndex];
    return Scaffold(
      body: page,
      bottomNavigationBar: _phoneBottomNav(),
    );
  }

  Widget _tabletLayout(BuildContext context) {
    final theme = Theme.of(context);
    final currentPage = pages[currentIndex];
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 80,
                color: theme.colorScheme.surfaceContainerLow,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Icon(
                        Icons.music_note,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Expanded(
                      child: NavigationRail(
                        selectedIndex: currentIndex,
                        onDestinationSelected: onTabChanged,
                        labelType: NavigationRailLabelType.all,
                        backgroundColor: Colors.transparent,
                        destinations: tabs
                            .map((t) => NavigationRailDestination(
                                  icon: t.icon,
                                  selectedIcon: t.activeIcon,
                                  label: Text(t.label ?? ''),
                                ))
                            .toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => Navigator.pushNamed(context, '/search'),
                        tooltip: '搜索',
                      ),
                    ),
                  ],
                ),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant,
              ),
              Expanded(child: currentPage),
            ],
          ),
        ),
        _TabletPlayerBar(),
      ],
    );
  }
}

class _TabletPlayerBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (_, player, __) {
        if (player.currentSong == null) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        return Container(
          height: 64,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          padding: EdgeInsets.only(
            left: 16,
            right: 8,
            top: 4,
            bottom: MediaQuery.of(context).padding.bottom + 4,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: player.currentSong!.albumCoverUrl != null
                    ? Image.network(
                        player.currentSong!.albumCoverUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 48,
                          height: 48,
                          color: Colors.grey[800],
                          child: const Icon(Icons.music_note),
                        ),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey[800],
                        child: const Icon(Icons.music_note),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.currentSong!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      player.currentSong!.artistDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                    if (player.duration.inSeconds > 0)
                      LinearProgressIndicator(
                        value: player.progress,
                        backgroundColor: Colors.grey[800],
                        minHeight: 2,
                      ),
                  ],
                ),
              ),
              if (player.isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 24),
                  onPressed: player.playPrevious,
                ),
                IconButton(
                  icon: Icon(
                    player.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    size: 32,
                  ),
                  onPressed: player.togglePlayPause,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 24),
                  onPressed: player.playNext,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

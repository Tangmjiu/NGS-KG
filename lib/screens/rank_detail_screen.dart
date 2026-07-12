import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../widgets/staggered_fade_slide.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../utils/responsive.dart';
import '../widgets/desktop_route_wrapper.dart';
import '../widgets/desktop_song_table.dart';
import '../widgets/song_tile.dart';

class RankDetailScreen extends StatefulWidget {
  final int rankId;
  final String? rankName;

  const RankDetailScreen({super.key, required this.rankId, this.rankName});

  @override
  State<RankDetailScreen> createState() => _RankDetailScreenState();
}

class _RankDetailScreenState extends State<RankDetailScreen> {
  final MusicService _musicService = MusicService();
  List<Song>? _songs;
  bool _isLoading = true;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final songs = await _musicService.getRankAudios(widget.rankId);
      if (mounted) {
        setState(() {
          _songs = songs;
          _total = songs.length;
          _isLoading = false;
        });
      }
    } catch (e, s) { Log.e('rank_detail_screen', 'error', e, s);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      desktop: (_) => _buildDesktop(),
      mobile: (_) => _buildMobile(),
      tablet: (_) => _buildMobile(),
    );
  }

  Widget _buildDesktop() {
    return DesktopRouteWrapper(
      title: widget.rankName ?? '排行榜',
      child: StaggeredFadeSlide(
        index: 0,
        slideOffset: 12,
        child: _buildDesktopContent(),
      ),
    );
  }

  Widget _buildDesktopContent() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_songs == null || _songs!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.trending_up, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text('暂无歌曲', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ── Rank info header ──
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.trending_up, size: 40, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.rankName ?? '排行榜',
                        style: tt.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('$_total 首',
                        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: () => context
                          .read<PlayerProvider>()
                          .playSong(_songs!.first, playlist: _songs),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('播放全部'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // ── Song table ──
        Expanded(
          child: DesktopSongTable(
            songs: _songs!,
            emptyMessage: '暂无歌曲',
          ),
        ),
      ],
    );
  }

  Widget _buildMobile() {
    final isWide = MediaQuery.of(context).size.width >= 880;
    final bodyContent = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _songs == null || _songs!.isEmpty
            ? const Center(child: Text('暂无歌曲'))
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8),
                itemCount: _songs!.length,
                itemBuilder: (_, i) {
                  final song = _songs![i];
                  return Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Center(
                          child: Text('${i + 1}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: i < 3
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline,
                              )),
                        ),
                      ),
                      Expanded(
                        child: SongTile(
                          song: song,
                          onTap: (s) => context
                              .read<PlayerProvider>()
                              .playSong(s, playlist: _songs),
                        ),
                      ),
                    ],
                  );
                },
              );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rankName ?? '排行榜'),
        bottom: _songs != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('共 $_total 首',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                ),
              )
            : null,
      ),
      body: isWide
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: bodyContent,
              ),
            )
          : bodyContent,
    );
  }
}

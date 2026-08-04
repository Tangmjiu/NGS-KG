import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../utils/responsive.dart';
import '../widgets/detail_banner.dart';
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
  String _coverUrl = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _musicService.getRankAudios(widget.rankId),
        _musicService.getRankList(),
      ]);
      final songs = results[0] as List<Song>;
      final ranks = results[1] as List;
      String cover = '';
      for (final r in ranks) {
        if (r.id == widget.rankId) {
          cover = r.coverUrl ?? r.bannerUrl ?? '';
          break;
        }
      }
      if (mounted) {
        setState(() {
          _songs = songs;
          _total = songs.length;
          _coverUrl = cover;
          _isLoading = false;
        });
      }
    } catch (e, s) {
      Log.e('rank_detail_screen', 'error', e, s);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktopLayout(context);
    final songs = _songs;
    final bodyContent = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : songs == null || songs.isEmpty
            ? const Center(child: Text('暂无歌曲'))
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8),
                itemCount: songs.length,
                itemBuilder: (_, i) {
                  final song = songs[i];
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
                              .playSong(s, playlist: songs),
                        ),
                      ),
                    ],
                  );
                },
              );
    // Banner 全宽出血, 列表全宽
    final content = isDesktop && songs != null && songs.isNotEmpty
        ? Column(
            children: [
              DetailBanner(
                coverUrl: _coverUrl.isEmpty ? null : _coverUrl,
                label: '排行榜',
                title: widget.rankName ?? '排行榜',
                stats: [
                  (value: '$_total', label: '首歌曲'),
                ],
                actions: Row(
                  children: [
                    PlayAllButton(
                      onPressed: () => context.read<PlayerProvider>().playSong(
                            songs.first,
                            playlist: songs,
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(child: bodyContent),
            ],
          )
        : bodyContent;
    return Scaffold(
      appBar: Responsive.isDesktopLayout(context)
          ? null
          : AppBar(
              title: Text(widget.rankName ?? '排行榜'),
              bottom: _songs != null
                  ? PreferredSize(
                      preferredSize: const Size.fromHeight(24),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('共 $_total 首',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                      ),
                    )
                  : null,
            ),
      body: Responsive.isDesktopLayout(context)
          ? content
          : Responsive.constrainedContent(
              context,
              maxWidth: Responsive.maxWidthList,
              child: content,
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
import '../widgets/song_tile.dart';
import '../utils/responsive.dart';
import '../widgets/song_grid_tile.dart';

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
    final bodyContent = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _songs == null || _songs!.isEmpty
            ? const Center(child: Text('暂无歌曲'))
            // ✅ 新增适配代码：平板网格封面墙（保留排名角标）/ 手机线性列表（保留排名号）
            : context.isTablet
                ? GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      childAspectRatio: 0.75,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                    ),
                    itemCount: _songs!.length,
                    itemBuilder: (_, i) {
                      final song = _songs![i];
                      return SongGridTile(
                        song: song,
                        rank: i + 1,
                        onTap: (s) => context
                            .read<PlayerProvider>()
                            .playSong(s, playlist: _songs),
                      );
                    },
                  )
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              )
            : null,
      ),
      body: bodyContent,
    );
  }
}

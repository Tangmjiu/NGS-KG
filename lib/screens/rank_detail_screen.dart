import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../utils/logger.dart';
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
    } catch (e, s) {
      Log.e('rank_detail_screen', 'error', e, s);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 880;
    final bodyContent = _buildBody();
    return Scaffold(
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

  /// M3 LargeTopAppBar 列表：大标题随滚动收缩（rankName + 曲目数）
  Widget _buildBody() {
    final context = this.context;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_songs == null || _songs!.isEmpty) {
      return const Center(child: Text('暂无歌曲'));
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: Text(widget.rankName ?? '排行榜'),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text('共 $_total 首',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((_, i) {
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
          }, childCount: _songs!.length),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import '../utils/logger.dart';
import '../utils/responsive.dart';
import '../utils/theme.dart';
import '../services/music_service.dart';

class CloudDiskScreen extends StatefulWidget {
  const CloudDiskScreen({super.key});

  @override
  State<CloudDiskScreen> createState() => _CloudDiskScreenState();
}

class _CloudDiskScreenState extends State<CloudDiskScreen> {
  final MusicService _musicService = MusicService();
  List<Map<String, dynamic>> _songs = [];
  bool _isLoading = true;
  int? _playingIndex;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final songs = await _musicService.getUserCloudDisk();
      if (mounted)
        setState(() {
          _songs = songs;
          _error = null;
        });
    } catch (e, s) {
      Log.e('CloudDisk', 'load error', e, s);
      if (mounted) setState(() => _error = '加载失败，请下拉刷新重试');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _playSong(int index, Map<String, dynamic> item) async {
    setState(() => _playingIndex = index);
    final hash = item['hash'] as String?;
    if (hash == null || hash.isEmpty) {
      setState(() => _playingIndex = null);
      return;
    }
    try {
      final url = await _musicService.getCloudSongUrl(
        hash,
        albumId: item['albumId'] as int?,
        name: item['name'] as String?,
        albumAudioId: item['albumAudioId'] as int?,
      );
      if (!mounted) {
        return;
      }
      if (url.isEmpty) {
        if (mounted) {
          setState(() => _playingIndex = null);
        }
        return;
      }
      final song = Song(
        id: item['mixSongId'] as int? ?? hash.hashCode,
        name: item['name'] as String? ?? '',
        artists: [item['artist'] as String? ?? ''],
        albumName: item['albumName'] as String?,
        albumCoverUrl: item['cover'] as String?,
        duration: (item['duration'] as int?) ?? 0,
        hash: hash,
        mixSongId: item['mixSongId'] as int?,
        qualities: {'128': hash},
        filePath: url,
      );
      if (!mounted) {
        return;
      }
      await context.read<PlayerProvider>().playSong(song);
    } catch (e, s) {
      Log.e('CloudDisk', 'play error', e, s);
    }
    if (mounted) setState(() => _playingIndex = null);
  }

  Future<void> _deleteSong(int index, Map<String, dynamic> item) async {
    final name = item['name'] as String? ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除云盘歌曲'),
        content: Text('确定要从云盘中删除「$name」吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final hash = item['hash'] as String?;
    // 文档：优先使用 fileid（列表返回的 kv_id）与 album_audio_id
    final kvId = item['kvId'] as int?;
    final albumAudioId = item['albumAudioId'] as int?;
    try {
      await _musicService.deleteCloudSongs(
        hash: hash,
        fileids: kvId?.toString(),
        albumAudioIds: albumAudioId?.toString(),
      );
      if (mounted) {
        setState(() => _songs.removeAt(index));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除「$name」')),
        );
      }
    } catch (e, s) {
      Log.e('CloudDisk', 'delete error', e, s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除失败，请稍后重试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktopLayout(context);
    final bodyContent = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 80, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                ),
              )
            : _songs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off,
                            size: 80,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text('云盘暂无歌曲',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: _songs.length,
                      itemBuilder: (_, i) {
                        final item = _songs[i];
                        final name = item['name'] as String? ?? '';
                        final author = item['artist'] as String? ?? '';
                        final cover = item['cover'] as String?;
                        final isPlaying = _playingIndex == i;
                        return ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: AppShape.sm,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: isPlaying
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : cover != null && cover.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl:
                                            cover.replaceAll('{size}', '240'),
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Icon(
                                            Icons.cloud_done,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary),
                                      )
                                    : Icon(Icons.cloud_done,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                          ),
                          title: Text(name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(author,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                            tooltip: '删除',
                            onPressed: () => _deleteSong(i, item),
                          ),
                          enabled: !isPlaying,
                          onTap: isPlaying ? null : () => _playSong(i, item),
                        );
                      },
                    ),
                  );

    if (isDesktop) {
      return Scaffold(
        appBar: null,
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              alignment: Alignment.centerLeft,
              child: Text(
                '云盘歌曲',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Expanded(
              child: Responsive.constrainedContent(
                context,
                maxWidth: Responsive.maxWidthList,
                child: bodyContent,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('云盘')),
      body: bodyContent,
    );
  }
}

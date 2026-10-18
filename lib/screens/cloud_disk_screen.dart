// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import '../ui/app_ui.dart';
import '../ui/components/cover_art.dart';
import '../ui/components/player_bottom_padding.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import '../utils/logger.dart';
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
  bool _loadInFlight = false;
  int _playRequestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loadInFlight) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _loadInFlight = true;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final songs = await _musicService.getUserCloudDisk();
      if (mounted) setState(() => _songs = songs);
    } catch (error, stack) {
      Log.e('CloudDisk', 'load error', error, stack);
      if (mounted) setState(() => _error = '暂时无法加载音乐云盘，请重试');
    } finally {
      _loadInFlight = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _playSong(int index, Map<String, dynamic> item) async {
    final request = ++_playRequestId;
    setState(() => _playingIndex = index);
    final hash = item['hash'] as String?;
    if (hash == null) {
      setState(() => _playingIndex = null);
      return;
    }
    try {
      final url = await _musicService.getCloudSongUrl(
        hash,
        albumId: item['album_id'] as int?,
        name: item['name'] as String?,
        albumAudioId: item['album_audio_id'] as int?,
      );
      if (!mounted || request != _playRequestId) return;
      if (url.isEmpty) return;
      final song = Song(
        id: hash.hashCode,
        name: item['name'] as String? ?? '',
        artists: [item['author_name'] as String? ?? ''],
        albumName: item['album_name'] as String?,
        albumCoverUrl: item['cover'] as String?,
        duration: ((item['timelength'] as int?) ?? 0) ~/ 1000,
        hash: hash,
        mixSongId: int.tryParse(item['mixsongid']?.toString() ?? ''),
        qualities: hash.isNotEmpty ? {'128': hash} : null,
        filePath: url,
      );
      await context.read<PlayerProvider>().playSong(song);
    } catch (error, stack) {
      Log.e('CloudDisk', 'play error', error, stack);
    } finally {
      if (mounted && request == _playRequestId) {
        setState(() => _playingIndex = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<AuthProvider>().isLoggedIn;
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AppPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: '音乐云盘',
                subtitle:
                    _songs.isEmpty ? '随时聆听保存于云端的音乐' : '${_songs.length} 首云端收藏',
                showBack: true,
              ),
              Expanded(
                child: !loggedIn
                    ? AppEmptyState(
                        icon: Icons.cloud_outlined,
                        title: '登录后访问音乐云盘',
                        message: '云端收藏会随账号同步。',
                        action: FilledButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/login').then((_) {
                            if (mounted) _load();
                          }),
                          child: const Text('登录音乐账号'),
                        ),
                      )
                    : _isLoading && _songs.isEmpty
                        ? const Center(child: AppLoadingIndicator())
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: CustomScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                if (_songs.isEmpty)
                                  SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: AppEmptyState(
                                      icon: _error == null
                                          ? Icons.cloud_queue_rounded
                                          : Icons.cloud_off_rounded,
                                      title: _error == null
                                          ? '云盘还没有歌曲'
                                          : '音乐云盘加载失败',
                                      message: _error ?? '上传到音乐账号的歌曲会显示在这里。',
                                      action: TextButton(
                                          onPressed: _load,
                                          child: const Text('刷新云盘')),
                                    ),
                                  )
                                else ...[
                                  if (_error != null)
                                    SliverPadding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: tokens.pagePadding),
                                      sliver: SliverToBoxAdapter(
                                          child: AppSurface(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(_error!),
                                            TextButton(
                                                onPressed: _load,
                                                child: const Text('重试')),
                                          ],
                                        ),
                                      )),
                                    ),
                                  SliverPadding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: tokens.pagePadding),
                                    sliver: SliverList.builder(
                                      itemCount: _songs.length,
                                      itemBuilder: (_, index) =>
                                          _songRow(index, _songs[index]),
                                    ),
                                  ),
                                  const SliverToBoxAdapter(
                                      child: PlayerBottomPadding(
                                          showLabel: false)),
                                ],
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _songRow(int index, Map<String, dynamic> item) {
    final pending = _playingIndex == index;
    final tokens = AppThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppSurface(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: pending
              ? const SizedBox(
                  width: 48,
                  height: 48,
                  child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : CoverArt(
                  url: (item['cover'] as String?)?.replaceAll('{size}', '480'),
                  size: 48,
                  borderRadius: tokens.controlRadius,
                  placeholder:
                      Icon(Icons.cloud_done_outlined, color: cs.primary),
                ),
          title: Text(item['name'] as String? ?? '',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(item['author_name'] as String? ?? '',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: pending
              ? null
              : Icon(Icons.play_arrow_rounded, color: cs.primary),
          enabled: !pending,
          onTap: pending ? null : () => _playSong(index, item),
        ),
      ),
    );
  }
}

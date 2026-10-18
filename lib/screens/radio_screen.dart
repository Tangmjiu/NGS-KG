// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/radio.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../ui/app_ui.dart';
import '../utils/logger.dart';
import '../ui/components/player_bottom_padding.dart';
import '../ui/components/cover_art.dart';

class RadioScreen extends StatefulWidget {
  final MusicService? musicService;

  const RadioScreen({super.key, this.musicService});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  late final MusicService _service = widget.musicService ?? MusicService();
  List<RadioStation> _stations = [];
  List<Song> _songs = [];
  bool _loading = true;
  bool _loadingSongs = false;
  bool _failed = false;
  bool _songsFailed = false;
  int? _selectedStation;
  int _songRequest = 0;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final stations = await _service.getFmRecommend();
      if (mounted) setState(() => _stations = stations);
    } catch (error, stack) {
      Log.e('RadioScreen', 'load stations', error, stack);
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSongs(int stationId) async {
    final request = ++_songRequest;
    setState(() {
      _loadingSongs = true;
      _songsFailed = false;
    });
    bool isCurrent() =>
        mounted && request == _songRequest && _selectedStation == stationId;
    try {
      final songs = await _service.getFmSongs(stationId);
      if (isCurrent()) setState(() => _songs = songs);
    } catch (error, stack) {
      Log.e('RadioScreen', 'load station songs', error, stack);
      if (isCurrent()) setState(() => _songsFailed = true);
    } finally {
      if (isCurrent()) setState(() => _loadingSongs = false);
    }
  }

  void _selectStation(RadioStation station) {
    ++_songRequest;
    final collapse = _selectedStation == station.id;
    setState(() {
      _selectedStation = collapse ? null : station.id;
      _songs = [];
      _songsFailed = false;
      _loadingSongs = false;
    });
    if (!collapse) _loadSongs(station.id);
  }

  void _play(Song song, int stationId) {
    final player = context.read<PlayerProvider>();
    player.playSong(song, playlist: _songs);
    player.playlistEndProvider = () => _service.getFmSongs(stationId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              tooltip: '刷新电台',
              onPressed: _loading ? null : _loadStations,
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: AppPageBody(
          child: _loading
              ? const Center(child: AppLoadingIndicator())
              : _failed || _stations.isEmpty
                  ? AppEmptyState(
                      kind: _failed
                          ? AppEmptyStateKind.error
                          : AppEmptyStateKind.content,
                      icon: Icons.radio_rounded,
                      title: _failed ? '电台暂时无法加载' : '暂无推荐电台',
                      message: '稍后再来，或重新获取推荐。',
                      action: FilledButton.tonal(
                        onPressed: _loadStations,
                        child: const Text('重新加载'),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadStations,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          const SliverToBoxAdapter(
                            child: AppPageHeader(
                              title: '电台',
                              subtitle: '挑一个频道，让音乐接着播放。',
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.symmetric(
                              horizontal:
                                  AppThemeTokens.of(context).pagePadding,
                            ),
                            sliver: SliverList.builder(
                              itemCount: _stations.length,
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _stationCard(_stations[index]),
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: PlayerBottomPadding(showLabel: false),
                          ),
                        ],
                      ),
                    ),
        ),
      );

  Widget _stationCard(RadioStation station) {
    final colors = Theme.of(context).colorScheme;
    final selected = _selectedStation == station.id;
    return AppSurface(
      padding: EdgeInsets.zero,
      color: selected ? colors.secondaryContainer : colors.surfaceContainerLow,
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CoverArt(
              url: station.coverUrl?.replaceAll('{size}', '480'),
              size: 56,
              borderRadius: 18,
            ),
            title: Text(station.name,
                maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: station.description?.isNotEmpty == true
                ? Text(station.description!,
                    maxLines: 2, overflow: TextOverflow.ellipsis)
                : const Text('打开频道'),
            trailing: Icon(selected
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded),
            onTap: () => _selectStation(station),
          ),
          if (selected)
            if (_loadingSongs)
              const Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              )
            else if (_songsFailed || _songs.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: TextButton.icon(
                  onPressed: () => _loadSongs(station.id),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(_songsFailed ? '加载失败，点此重试' : '暂无歌曲，重新获取'),
                ),
              )
            else
              SizedBox(
                height: (MediaQuery.sizeOf(context).height * 0.4)
                    .clamp(200.0, 420.0),
                child: ListView.builder(
                  key: ValueKey(station.id),
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    return ListTile(
                      leading: CoverArt(url: song.thumbnailCoverUrl),
                      title: Text(song.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(song.artistDisplay,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.play_arrow_rounded),
                      onTap: () => _play(song, station.id),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }
}

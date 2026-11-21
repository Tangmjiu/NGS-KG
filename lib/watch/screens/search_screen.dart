// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../services/music_service.dart';
import '../widgets/watch_scaffold.dart';
import '../widgets/watch_scroll_list.dart';
import '../widgets/watch_song_tile.dart';

enum _SearchState { initial, searching, results, empty, error }

class WatchSearchScreen extends StatefulWidget {
  const WatchSearchScreen({super.key});

  @override
  State<WatchSearchScreen> createState() => _WatchSearchScreenState();
}

class _WatchSearchScreenState extends State<WatchSearchScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _revision = 0;
  List<Song> _songs = const [];
  _SearchState _state = _SearchState.initial;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        _focus.requestFocus();
      }
    });
  }

  void _query(String value, {bool submit = false}) {
    final keyword = value.trim();
    final revision = ++_revision;
    _timer?.cancel();
    setState(() {
      _songs = const [];
      _error = null;
      _state = keyword.isEmpty ? _SearchState.initial : _SearchState.searching;
    });
    if (keyword.isEmpty) return;
    if (submit) {
      _search(keyword, revision);
    } else {
      _timer = Timer(
        const Duration(milliseconds: 300),
        () => _search(keyword, revision),
      );
    }
  }

  Future<void> _search(String keyword, int revision) async {
    try {
      final songs = await context.read<MusicService>().search(
        keyword,
        limit: 20,
      );
      if (!mounted || revision != _revision) return;
      setState(() {
        _songs = songs;
        _state = songs.isEmpty ? _SearchState.empty : _SearchState.results;
      });
    } catch (error) {
      if (!mounted || revision != _revision) return;
      setState(() {
        _state = _SearchState.error;
        _error = error.toString();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = context.select((PlayerProvider p) => p.currentSong);
    final input = TextField(
      controller: _input,
      focusNode: _focus,
      textInputAction: TextInputAction.search,
      onChanged: _query,
      onSubmitted: (value) {
        _focus.unfocus();
        _query(value, submit: true);
      },
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHigh,
        hintText: '歌名或歌手',
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        prefixIconConstraints: const BoxConstraints(minWidth: 32),
        suffixIconConstraints: const BoxConstraints(minWidth: 34),
        suffixIcon: _input.text.isEmpty
            ? null
            : IconButton(
                tooltip: '清空搜索',
                iconSize: 16,
                onPressed: () {
                  _input.clear();
                  _query('');
                  _focus.requestFocus();
                },
                icon: const Icon(Icons.close_rounded),
              ),
        border: const OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.all(Radius.circular(40)),
        ),
      ),
    );
    return WatchScaffold(
      body: LayoutBuilder(
        builder: (_, constraints) {
          if (constraints.maxHeight < 88) {
            return Align(alignment: Alignment.topCenter, child: input);
          }
          return Column(
            children: [
              const WatchCatalogTitle('找歌'),
              input,
              Expanded(
                child: switch (_state) {
                  _SearchState.initial => const WatchCatalogNotice(
                    '想听哪首歌？',
                    icon: Icons.headphones_rounded,
                  ),
                  _SearchState.searching => const WatchCatalogNotice(
                    '正在找歌',
                    busy: true,
                  ),
                  _SearchState.empty => const WatchCatalogNotice(
                    '没找到这首歌',
                    icon: Icons.search_off_rounded,
                  ),
                  _SearchState.error => WatchCatalogNotice(
                    _error ?? '搜索失败',
                    icon: Icons.cloud_off_rounded,
                    action: TextButton(
                      onPressed: () => _query(_input.text, submit: true),
                      child: const Text('重试'),
                    ),
                  ),
                  _SearchState.results => WatchScrollList(
                    itemCount: _songs.length,
                    itemExtent: 52,
                    topPadding: 3,
                    itemBuilder: (context, index) {
                      final song = _songs[index];
                      return WatchSongTile.fromSong(
                        song: song,
                        isPlaying: watchSameSong(current, song),
                        onTap: () => context.read<PlayerProvider>().playSong(
                          song,
                          playlist: _songs,
                        ),
                      );
                    },
                  ),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

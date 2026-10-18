// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../models/artist.dart';
import '../services/music_service.dart';
import '../ui/app_ui.dart';
import '../ui/components/cover_art.dart';
import '../utils/logger.dart';

class ArtistListScreen extends StatefulWidget {
  const ArtistListScreen({super.key});

  @override
  State<ArtistListScreen> createState() => _ArtistListScreenState();
}

class _ArtistListScreenState extends State<ArtistListScreen> {
  final MusicService _musicService = MusicService();
  List<Artist> _artists = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final artists = await _musicService.getArtistList();
      if (mounted) setState(() => _artists = artists);
    } catch (error, stack) {
      Log.e('artist_list_screen', 'load error', error, stack);
      if (mounted) setState(() => _error = '暂时无法加载歌手，请重试');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final scale = MediaQuery.textScalerOf(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AppPageBody(
          child: RefreshIndicator(
            onRefresh: _load,
            child: LayoutBuilder(builder: (context, constraints) {
              final available = constraints.maxWidth - 2 * tokens.pagePadding;
              final columns =
                  available < 250 || (scale.scale(14) > 22 && available < 600)
                      ? 1
                      : (available / 160).floor().clamp(2, 6).toInt();
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(
                      child: AppPageHeader(
                    title: '歌手',
                    subtitle: '从喜欢的声音，发现更多音乐',
                    showBack: true,
                  )),
                  if (_artists.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _isLoading
                          ? const Center(child: AppLoadingIndicator())
                          : AppEmptyState(
                              icon: _error == null
                                  ? Icons.mic_none_rounded
                                  : Icons.cloud_off_rounded,
                              title: _error == null ? '暂时没有歌手' : '歌手加载失败',
                              message: _error ?? '下拉刷新，继续寻找喜欢的声音。',
                              action: TextButton(
                                  onPressed: _load, child: const Text('重新加载')),
                            ),
                    )
                  else ...[
                    if (_error != null)
                      SliverToBoxAdapter(
                          child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: tokens.pagePadding),
                        child: Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      )),
                    SliverPadding(
                      padding:
                          EdgeInsets.symmetric(horizontal: tokens.pagePadding),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: 124 + scale.scale(16) * 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _artists.length,
                        itemBuilder: (_, index) => _artistCard(_artists[index]),
                      ),
                    ),
                    SliverToBoxAdapter(
                        child: SizedBox(
                            height: 32 + MediaQuery.paddingOf(context).bottom)),
                  ],
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _artistCard(Artist artist) => AppSurface(
        padding: const EdgeInsets.all(16),
        onTap: () => Navigator.pushNamed(context, '/artist/detail',
            arguments: {'id': artist.id, 'name': artist.name}),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CoverArt(
              url: artist.picUrl?.replaceAll('{size}', '480'),
              size: 80,
              borderRadius: 40,
              placeholder: const Icon(Icons.person_outline_rounded, size: 36),
            ),
            const SizedBox(height: 12),
            Text(artist.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
}

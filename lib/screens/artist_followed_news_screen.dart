// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../services/music_service.dart';
import '../ui/app_ui.dart';
import '../utils/logger.dart';

class ArtistFollowedNewsScreen extends StatefulWidget {
  const ArtistFollowedNewsScreen({super.key});

  @override
  State<ArtistFollowedNewsScreen> createState() =>
      _ArtistFollowedNewsScreenState();
}

class _ArtistFollowedNewsScreenState extends State<ArtistFollowedNewsScreen> {
  final MusicService _musicService = MusicService();
  List<Map<String, dynamic>> _news = [];
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
      final news = await _musicService.getFollowedArtistNews();
      if (mounted) setState(() => _news = news);
    } catch (error, stack) {
      Log.e('artist_followed_news_screen', 'load error', error, stack);
      if (mounted) setState(() => _error = '暂时无法加载关注动态，请重试');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AppPageBody(
          child: RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(
                    child: AppPageHeader(
                  title: '关注动态',
                  subtitle: '不错过喜欢的歌手的新消息',
                  showBack: true,
                )),
                if (_news.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _isLoading
                        ? const Center(child: AppLoadingIndicator())
                        : AppEmptyState(
                            icon: _error == null
                                ? Icons.person_add_alt_rounded
                                : Icons.cloud_off_rounded,
                            title: _error == null ? '还没有新的动态' : '动态加载失败',
                            message: _error ?? '关注歌手后，他们的最新消息会出现在这里。',
                            action: TextButton(
                                onPressed: _load, child: const Text('刷新动态')),
                          ),
                  )
                else ...[
                  if (_error != null)
                    SliverToBoxAdapter(
                        child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: tokens.pagePadding),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    )),
                  SliverPadding(
                    padding:
                        EdgeInsets.symmetric(horizontal: tokens.pagePadding),
                    sliver: SliverList.builder(
                      itemCount: _news.length,
                      itemBuilder: (_, index) => _newsCard(_news[index]),
                    ),
                  ),
                  SliverToBoxAdapter(
                      child: SizedBox(
                          height: 32 + MediaQuery.paddingOf(context).bottom)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _newsCard(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Icon(Icons.person_outline_rounded,
                    color: theme.colorScheme.onSecondaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(item['artist'] as String? ?? '关注歌手',
                      style: theme.textTheme.titleMedium)),
            ]),
            const SizedBox(height: 16),
            Text(item['content'] as String? ?? item['title'] as String? ?? '',
                style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

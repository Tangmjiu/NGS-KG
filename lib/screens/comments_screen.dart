// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../models/artist.dart';
import '../services/music_service.dart';
import '../ui/app_ui.dart';
import '../ui/components/cover_art.dart';
import '../ui/components/player_bottom_padding.dart';
import '../utils/logger.dart';

class CommentsScreen extends StatefulWidget {
  final String type;
  final int id;
  final MusicService? musicService;

  const CommentsScreen({
    super.key,
    required this.type,
    required this.id,
    this.musicService,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  late MusicService _musicService;
  List<Comment> _comments = [];
  bool _isLoading = false;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _musicService = widget.musicService ?? MusicService();
    _load();
  }

  @override
  void didUpdateWidget(covariant CommentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.musicService != widget.musicService) {
      _musicService = widget.musicService ?? MusicService();
    }
    if (oldWidget.id != widget.id ||
        oldWidget.type != widget.type ||
        oldWidget.musicService != widget.musicService) {
      _load(reset: true);
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_isLoading && !reset) return;
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _error = null;
      if (reset) _comments = [];
    });
    try {
      final comments = widget.type == 'music'
          ? await _musicService.getMusicComments(widget.id)
          : await _musicService.getPlaylistComments(widget.id);
      if (!mounted || requestId != _requestId) return;
      setState(() => _comments = comments);
    } catch (error, stack) {
      Log.e('Comments', 'load error', error, stack);
      if (!mounted || requestId != _requestId) return;
      setState(() => _error = '评论暂时无法加载，请稍后重试');
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AppPageBody(
          child: RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: AppPageHeader(
                    title: '评论',
                    subtitle: _comments.isEmpty
                        ? '听见音乐，也听见彼此'
                        : '${_comments.length} 条评论 · 分享听歌感受',
                    showBack: true,
                    actions: [
                      IconButton(
                        tooltip: '刷新评论',
                        onPressed: _isLoading ? null : _load,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          tokens.pagePadding, 0, tokens.pagePadding, 20),
                      child: const LinearProgressIndicator(),
                    ),
                  ),
                if (!_isLoading && _comments.isEmpty)
                  SliverToBoxAdapter(
                    child: AppEmptyState(
                      icon: _error != null
                          ? Icons.cloud_off_rounded
                          : Icons.chat_bubble_outline_rounded,
                      title: _error != null ? '评论加载失败' : '暂无评论',
                      message: _error ?? '这里还没有人留下评论',
                      action: _error == null
                          ? null
                          : FilledButton.tonalIcon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('重试'),
                            ),
                    ),
                  ),
                if (_error != null && _comments.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          tokens.pagePadding, 0, tokens.pagePadding, 16),
                      child: AppSurface(
                        color: cs.errorContainer,
                        child: Row(children: [
                          Expanded(
                            child: Text(_error!,
                                style: TextStyle(color: cs.onErrorContainer)),
                          ),
                          IconButton(
                            tooltip: '重试加载评论',
                            onPressed: _load,
                            color: cs.onErrorContainer,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ]),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: tokens.pagePadding),
                  sliver: SliverList.builder(
                    itemCount: _comments.length,
                    itemBuilder: (_, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CommentCard(comment: _comments[index]),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: PlayerBottomPadding()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final Comment comment;

  const _CommentCard({required this.comment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AppSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CoverArt(
              url: comment.userAvatar?.replaceAll('{size}', '480'),
              size: 36,
              borderRadius: 18,
              placeholder: Icon(Icons.person_rounded,
                  size: 20, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                comment.userName?.trim().isNotEmpty == true
                    ? comment.userName!
                    : '匿名',
                style: theme.textTheme.titleSmall,
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Text(comment.content,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (comment.time?.isNotEmpty == true)
                Text(comment.time!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              Semantics(
                label: '${comment.likedCount} 人点赞',
                excludeSemantics: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.thumb_up_outlined,
                        size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('${comment.likedCount}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

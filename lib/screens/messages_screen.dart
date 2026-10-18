// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../services/music_service.dart';
import '../ui/app_ui.dart';
import '../utils/logger.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
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
      Log.e('Messages', 'load error', error, stack);
      if (mounted) setState(() => _error = '暂时无法同步关注动态');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                  tokens.pagePadding,
                  20,
                  tokens.pagePadding,
                  32 + MediaQuery.paddingOf(context).bottom),
              children: [
                const AppPageHeader(
                  padding: EdgeInsets.zero,
                  title: '消息',
                  subtitle: '关注喜欢的声音，收下最新动态',
                  showBack: true,
                ),
                SizedBox(height: tokens.sectionSpacing),
                AppSurface(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading:
                        Icon(Icons.person_add_alt_rounded, color: cs.primary),
                    title: const Text('关注歌手消息'),
                    subtitle: Text(_isLoading
                        ? '正在同步关注动态'
                        : _error ?? '${_news.length} 条动态'),
                    trailing: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        Navigator.pushNamed(context, '/artist/followed/news'),
                  ),
                ),
                if (_error != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child:
                        TextButton(onPressed: _load, child: const Text('重新同步')),
                  ),
                SizedBox(height: tokens.sectionSpacing),
                const AppSectionHeader(
                    padding: EdgeInsets.zero, title: '通知与互动'),
                const SizedBox(height: 12),
                const AppSurface(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Column(children: [
                    ListTile(
                      leading: Icon(Icons.notifications_none_rounded),
                      title: Text('系统通知'),
                      subtitle: Text('暂无新通知'),
                    ),
                    Divider(indent: 20, endIndent: 20, height: 1),
                    ListTile(
                      leading: Icon(Icons.favorite_border_rounded),
                      title: Text('点赞与收藏'),
                      subtitle: Text('暂无新消息'),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

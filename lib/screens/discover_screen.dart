import 'package:flutter/material.dart';
import '../models/playlist_tag.dart';
import '../models/radio.dart';
import '../services/music_service.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final MusicService _musicService = MusicService();
  List<PlaylistTag> _playlistTags = [];
  List<RadioStation> _fmList = [];
  bool _loadingTags = true;
  bool _loadingFm = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
    _loadFm();
  }

  Future<void> _loadTags() async {
    try {
      final tags = await _musicService.getPlaylistTags();
      if (mounted) setState(() => _playlistTags = tags);
    } catch (e) {
      debugPrint('[Discover] loadTags error: $e');
    }
    if (mounted) setState(() => _loadingTags = false);
  }

  Future<void> _loadFm() async {
    try {
      final fm = await _musicService.getFmRecommend();
      if (mounted) setState(() => _fmList = fm.take(6).toList());
    } catch (e) {
      debugPrint('[Discover] loadFm error: $e');
    }
    if (mounted) setState(() => _loadingFm = false);
  }

  List<Widget> _buildTagChips() {
    final chips = <Widget>[];
    for (final t in _playlistTags) {
      final name = t.name;
      final tagId = t.id;
      final son = t.children ?? [];
      if (son.isNotEmpty) {
        chips.add(Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 4),
          child: PopupMenuButton<int>(
            child: Chip(
              label: Text(name, style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
            ),
            itemBuilder: (context) => son.map((s) {
              return PopupMenuItem(
                value: s.id,
                child: Text(s.name),
              );
            }).toList(),
            onSelected: (id) {
              if (id > 0) {
                final selectedName = son.firstWhere(
                  (s) => s.id == id,
                  orElse: () => PlaylistTag(id: 0, name: name),
                ).name;
                Navigator.pushNamed(context, '/playlist/category', arguments: {'id': id, 'name': selectedName});
              }
            },
          ),
        ));
      } else {
        if (tagId > 0) {
          chips.add(ActionChip(
            label: Text(name, style: const TextStyle(fontSize: 12)),
            onPressed: () {
              Navigator.pushNamed(context, '/playlist/category', arguments: {'id': tagId, 'name': name});
            },
            visualDensity: VisualDensity.compact,
          ));
        }
      }
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_loadTags(), _loadFm()]);
      },
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('发现',
                style: Theme.of(context).textTheme.headlineSmall),
          ),
          // 快捷入口卡片
          if (!_loadingFm && _fmList.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('电台',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _fmList.length,
                itemBuilder: (_, i) {
                  final fm = _fmList[i];
                  final name = fm.name;
                  final img = (fm.coverUrl ?? '').replaceAll('{size}', '240');
                  return GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/fm', arguments: {'fmid': fm.id, 'name': name}),
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: img.isNotEmpty
                                ? Image.network(img, width: 80, height: 80, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.radio)))
                                : Container(width: 80, height: 80, color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.radio)),
                          ),
                          const SizedBox(height: 4),
                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else if (_loadingFm) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('电台', style: Theme.of(context).textTheme.titleLarge),
            ),
            const Center(child: CircularProgressIndicator()),
          ],
          const SizedBox(height: 16),
          // 歌单分类
          if (!_loadingTags && _playlistTags.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('歌单分类',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _buildTagChips(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/music_service.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final MusicService _musicService = MusicService();
  List<Map<String, dynamic>> _playlistTags = [];
  List<Map<String, dynamic>> _fmList = [];
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
    } catch (_) {}
    if (mounted) setState(() => _loadingTags = false);
  }

  Future<void> _loadFm() async {
    try {
      final fm = await _musicService.getFmRecommend();
      if (mounted) setState(() => _fmList = fm.take(6).toList());
    } catch (_) {}
    if (mounted) setState(() => _loadingFm = false);
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
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('发现',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          // 快捷入口
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _quickLink(Icons.radio, '电台', '/fm'),
              _quickLink(Icons.music_note, '曲谱', '/sheet/list'),
            ],
          ),
          const SizedBox(height: 16),
          // 歌单分类
          if (!_loadingTags && _playlistTags.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('歌单分类',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _playlistTags.length,
                itemBuilder: (_, i) {
                  final tag = _playlistTags[i];
                  final name = tag['tag_name'] as String? ?? '';
                  final id = tag['tag_id'] as int? ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(name),
                      onPressed: () => Navigator.pushNamed(
                          context, '/playlist/tag',
                          arguments: {'tagId': id, 'name': name}),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          // 推荐电台
          if (!_loadingFm && _fmList.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('推荐电台',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _fmList.length,
                itemBuilder: (_, i) {
                  final fm = _fmList[i];
                  final name = fm['fmname'] as String? ?? '';
                  final img = (fm['imgurl'] as String? ?? '').replaceAll(
                      '{size}', '240');
                  return GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/fm'),
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: img.isNotEmpty
                                ? Image.network(img,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Container(
                                            width: 80,
                                            height: 80,
                                            color: Colors.grey[800],
                                            child: const Icon(Icons.radio)))
                                : Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.radio)),
                          ),
                          const SizedBox(height: 4),
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quickLink(IconData icon, String label, String route) {
    return Column(
      children: [
        IconButton(
          onPressed: () => Navigator.pushNamed(context, route),
          icon: Icon(icon, size: 32),
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey[800],
            fixedSize: const Size(56, 56),
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

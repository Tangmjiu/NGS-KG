import 'package:flutter/material.dart';
import '../services/music_service.dart';

class SheetListScreen extends StatefulWidget {
  const SheetListScreen({super.key});

  @override
  State<SheetListScreen> createState() => _SheetListScreenState();
}

class _SheetListScreenState extends State<SheetListScreen> {
  final MusicService _musicService = MusicService();
  List<Map<String, dynamic>> _sheets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _musicService.getSheetList();
      if (mounted) setState(() => _sheets = list);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('曲谱')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sheets.isEmpty
              ? const Center(child: Text('暂无曲谱'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _sheets.length,
                  itemBuilder: (_, i) {
                    final sheet = _sheets[i];
                    final name = sheet['name'] as String? ?? sheet['title'] as String? ?? '';
                    final artist = sheet['artist'] as String? ?? sheet['singer'] as String? ?? '';
                    final img = sheet['imgUrl'] as String? ?? sheet['coverImgUrl'] as String?;
                    return Card(
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: img != null
                              ? Image.network(img, width: 48, height: 48, fit: BoxFit.cover)
                              : Container(width: 48, height: 48, color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.music_note)),
                        ),
                        title: Text(name, maxLines: 1),
                        subtitle: Text(artist, maxLines: 1),
                        onTap: () => Navigator.pushNamed(context, '/sheet/detail',
                            arguments: {'id': sheet['id'] as int? ?? 0, 'name': name}),
                      ),
                    );
                  },
                ),
    );
  }
}

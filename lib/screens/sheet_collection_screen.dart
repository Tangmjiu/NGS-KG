import 'package:flutter/material.dart';
import '../services/music_service.dart';

class SheetCollectionScreen extends StatefulWidget {
  const SheetCollectionScreen({super.key});

  @override
  State<SheetCollectionScreen> createState() => _SheetCollectionScreenState();
}

class _SheetCollectionScreenState extends State<SheetCollectionScreen> {
  final MusicService _musicService = MusicService();
  List<Map<String, dynamic>> _collections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _musicService.getSheetCollections();
      if (mounted) setState(() => _collections = list);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('曲谱合集')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _collections.isEmpty
              ? const Center(child: Text('暂无曲谱合集'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _collections.length,
                  itemBuilder: (_, i) {
                    final c = _collections[i];
                    final name = c['name'] as String? ?? '';
                    final id = c['id'] as int? ?? 0;
                    return Card(
                      child: ListTile(
                        title: Text(name),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pushNamed(
                            context, '/sheet/collection/detail',
                            arguments: {'id': id, 'name': name}),
                      ),
                    );
                  },
                ),
    );
  }
}

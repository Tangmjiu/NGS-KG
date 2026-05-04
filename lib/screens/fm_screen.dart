import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';

class FmScreen extends StatefulWidget {
  const FmScreen({super.key});

  @override
  State<FmScreen> createState() => _FmScreenState();
}

class _FmScreenState extends State<FmScreen> {
  final MusicService _musicService = MusicService();
  List<Map<String, dynamic>> _radios = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _musicService.getFmRecommend();
      if (mounted) setState(() => _radios = list);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('电台')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _radios.isEmpty
              ? const Center(child: Text('暂无电台'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _radios.length,
                  itemBuilder: (_, i) {
                    final radio = _radios[i];
                    final name = radio['name'] as String? ?? '';
                    final desc = radio['description'] as String? ?? '';
                    final img = radio['picUrl'] as String? ?? radio['imgUrl'] as String?;
                    final id = radio['id'] as int? ?? radio['fmId'] as int? ?? 0;
                    return Card(
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: img != null
                              ? Image.network(img, width: 48, height: 48, fit: BoxFit.cover)
                              : Container(width: 48, height: 48, color: Colors.grey[800], child: const Icon(Icons.radio)),
                        ),
                        title: Text(name, maxLines: 1),
                        subtitle: Text(desc, maxLines: 1),
                        onTap: () async {
                          try {
                            final songs = await _musicService.getFmSongs(id);
                            if (songs.isNotEmpty && context.mounted) {
                              context.read<PlayerProvider>().playSong(songs[0], playlist: songs);
                            }
                          } catch (_) {}
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
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

  void _playRadio(Map<String, dynamic> radio) {
    final songs = (radio['rcmdlist'] as List<dynamic>?)
            ?.map((e) => Song.fromTrackJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    if (songs.isEmpty) {
      final fmid = radio['fmid'] as int?;
      if (fmid != null) {
        _musicService.getFmSongs(fmid).then((s) {
          if (s.isNotEmpty && mounted) {
            context.read<PlayerProvider>().playSong(s[0], playlist: s);
          }
        });
      }
      return;
    }
    context.read<PlayerProvider>().playSong(songs[0], playlist: songs);
  }

  String _coverUrl(Map<String, dynamic> radio) {
    final url = radio['imgurl'] as String? ?? '';
    if (url.isEmpty) return '';
    return url.replaceAll('{size}', '240');
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
                    final name = radio['fmname'] as String? ?? '';
                    final desc = radio['description'] as String? ?? '';
                    final img = _coverUrl(radio);
                    return Card(
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: img.isNotEmpty
                              ? Image.network(img,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                      width: 48,
                                      height: 48,
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.radio)))
                              : Container(
                                  width: 48,
                                  height: 48,
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.radio)),
                        ),
                        title: Text(name, maxLines: 1),
                        subtitle: Text(desc,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.play_circle_outline),
                        onTap: () => _playRadio(radio),
                      ),
                    );
                  },
                ),
    );
  }
}

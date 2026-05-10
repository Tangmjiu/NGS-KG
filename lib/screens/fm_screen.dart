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
  int? _selectedFmid;
  List<Song> _fmSongs = [];
  bool _loadingSongs = false;

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

  Future<void> _loadFmSongs() async {
    setState(() => _loadingSongs = true);
    try {
      final songs = await _musicService.getFmSongs();
      if (mounted) setState(() => _fmSongs = songs);
    } catch (_) {}
    if (mounted) setState(() => _loadingSongs = false);
  }

  void _onRadioTap(Map<String, dynamic> radio) {
    final fmid = radio['fmid'] as int?;
    if (fmid == null) return;
    final newFmid = _selectedFmid == fmid ? null : fmid;
    setState(() {
      _selectedFmid = newFmid;
      if (newFmid != null) {
        _fmSongs = [];
      }
    });
    if (newFmid != null) {
      _loadFmSongs();
    }
  }

  void _playSong(Song song) {
    context.read<PlayerProvider>().playSong(song, playlist: _fmSongs);
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
                    final fmid = radio['fmid'] as int?;
                    final isExpanded = _selectedFmid == fmid;
                    return Column(
                      children: [
                        Card(
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: img.isNotEmpty
                                  ? Image.network(img, width: 48, height: 48, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: Colors.grey[800], child: const Icon(Icons.radio)))
                                  : Container(width: 48, height: 48, color: Colors.grey[800], child: const Icon(Icons.radio)),
                            ),
                            title: Text(name, maxLines: 1),
                            subtitle: Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                            onTap: () => _onRadioTap(radio),
                          ),
                        ),
                        if (isExpanded)
                          _loadingSongs
                              ? const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())
                              : _fmSongs.isEmpty
                                  ? const Padding(padding: EdgeInsets.all(16), child: Text('暂无歌曲'))
                                  : Container(
                                      height: 200,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[900],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ListView.builder(
                                        itemCount: _fmSongs.length,
                                        itemBuilder: (_, j) {
                                          final song = _fmSongs[j];
                                          return ListTile(
                                            leading: const Icon(Icons.music_note),
                                            title: Text(song.name, maxLines: 1),
                                            subtitle: Text(song.artistDisplay, maxLines: 1),
                                            onTap: () => _playSong(song),
                                          );
                                        },
                                      ),
                                    ),
                      ],
                    );
                  },
                ),
    );
  }
}

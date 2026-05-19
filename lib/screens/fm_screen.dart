import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../models/radio.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';

class FmScreen extends StatefulWidget {
  const FmScreen({super.key});

  @override
  State<FmScreen> createState() => _FmScreenState();
}

class _FmScreenState extends State<FmScreen> {
  final MusicService _musicService = MusicService();
  List<RadioStation> _radios = [];
  List<Map<String, dynamic>> _yuekuFm = [];
  Map<int, String> _fmImages = {};
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
    await Future.wait([
      _loadFmRadios(),
      _loadYuekuFm(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadFmRadios() async {
    try {
      final list = await _musicService.getFmRecommend();
      if (mounted) setState(() => _radios = list);
      for (final r in list) {
        _loadFmImage(r.id);
      }
    } catch (_) {}
  }

  Future<void> _loadYuekuFm() async {
    try {
      final list = await _musicService.getYuekuRadio();
      if (mounted) setState(() => _yuekuFm = list);
    } catch (_) {}
  }

  Future<void> _loadFmImage(int fmid) async {
    try {
      final images = await _musicService.getRadioImages();
      for (final img in images) {
        final id = img['fmid'] as int? ?? (img['id'] as int? ?? 0);
        final url = img['imgurl'] as String? ?? img['img'] as String? ?? '';
        if (id == fmid && url.isNotEmpty) {
          _fmImages[fmid] = url.replaceAll('{size}', '240');
        }
      }
    } catch (_) {}
  }

  Future<void> _loadFmSongs(int fmid) async {
    setState(() => _loadingSongs = true);
    try {
      final songs = await _musicService.getFmSongs(fmid);
      if (mounted) setState(() => _fmSongs = songs);
    } catch (_) {}
    if (mounted) setState(() => _loadingSongs = false);
  }

  void _onRadioTap(RadioStation radio) {
    final fmid = radio.id;
    final wasExpanded = _selectedFmid == fmid;
    if (wasExpanded) {
      setState(() => _selectedFmid = null);
    } else {
      setState(() {
        _selectedFmid = fmid;
        _fmSongs = [];
      });
      _loadFmSongs(fmid);
    }
  }

  void _playSong(Song song) {
    context.read<PlayerProvider>().playSong(song, playlist: _fmSongs);
  }

  String _coverUrl(RadioStation radio) {
    final url = radio.coverUrl ?? '';
    if (url.isNotEmpty) return url.replaceAll('{size}', '240');
    final fallback = _fmImages[radio.id];
    return fallback ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('电台')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _radios.isEmpty && _yuekuFm.isEmpty
              ? const Center(child: Text('暂无电台'))
              : ListView(
                  children: [
                    if (_yuekuFm.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text('乐库电台', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _yuekuFm.length,
                          itemBuilder: (_, i) {
                            final fm = _yuekuFm[i];
                            final name = fm['name'] as String? ?? fm['title'] as String? ?? '';
                            final img = (fm['imgurl'] as String? ?? fm['img'] as String? ?? '').replaceAll('{size}', '240');
                            return GestureDetector(
                              onTap: () => _onYuekuTap(fm),
                              child: Container(
                                width: 80,
                                margin: const EdgeInsets.only(right: 12),
                                child: Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: img.isNotEmpty
                                          ? Image.network(img, width: 64, height: 64, fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(width: 64, height: 64, color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.radio)))
                                          : Container(width: 64, height: 64, color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.radio)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text('推荐电台', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    ..._buildRadioList(),
                  ],
                ),
    );
  }

  List<Widget> _buildRadioList() {
    return _radios.map((radio) {
      final name = radio.name;
      final desc = radio.description ?? '';
      final img = _coverUrl(radio);
      final fmid = radio.id;
      final isExpanded = _selectedFmid == fmid;
      return Column(
        children: [
          Card(
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: img.isNotEmpty
                    ? Image.network(img, width: 48, height: 48, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.radio)))
                    : Container(width: 48, height: 48, color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.radio)),
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
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          itemCount: _fmSongs.length,
                          itemBuilder: (_, j) {
                            final song = _fmSongs[j];
                            return ListTile(
                              leading: const Icon(Icons.music_note),
                              title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(song.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis),
                              onTap: () => _playSong(song),
                            );
                          },
                        ),
                      ),
        ],
      );
    }).toList();
  }

  void _onYuekuTap(Map<String, dynamic> fm) async {
    final fmid = fm['fmid'] as int? ?? fm['id'] as int? ?? 0;
    if (fmid > 0) {
      try {
        final songs = await _musicService.getFmSongs(fmid);
        if (songs.isNotEmpty && mounted) {
          context.read<PlayerProvider>().playSong(songs.first, playlist: songs);
        }
      } catch (_) {}
    }
  }
}

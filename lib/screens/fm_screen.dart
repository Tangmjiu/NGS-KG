import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../utils/responsive.dart';
import '../widgets/desktop_route_wrapper.dart';
import '../models/radio.dart';
import '../providers/player_provider.dart';
import '../utils/logger.dart';
import '../services/music_service.dart';

class FmScreen extends StatefulWidget {
  const FmScreen({super.key});

  @override
  State<FmScreen> createState() => _FmScreenState();
}

class _FmScreenState extends State<FmScreen> {
  final MusicService _musicService = MusicService();
  List<RadioStation> _radios = [];
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
    await _loadFmRadios();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadFmRadios() async {
    try {
      final list = await _musicService.getFmRecommend();
      if (mounted) setState(() => _radios = list);
    } catch (e, s) {
      Log.e('fm_screen', 'error', e, s);
    }
  }

  Future<void> _loadFmSongs(int fmid) async {
    setState(() => _loadingSongs = true);
    try {
      final songs = await _musicService.getFmSongs(fmid);
      if (mounted) setState(() => _fmSongs = songs);
    } catch (e, s) {
      Log.e('fm_screen', 'error', e, s);
    }
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
    try {
      final player = context.read<PlayerProvider>();
      final fmid = _selectedFmid;
      if (fmid == null) return;
      player.playlistEndProvider = () => _musicService.getFmSongs(fmid);
      player.playSong(song, playlist: _fmSongs);
    } catch (e, s) {
      Log.e('fm_screen', 'playSong error', e, s);
    }
  }



  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final bodyContent = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _radios.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.radio, size: 80, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    Text('暂无电台', style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              )
            : ListView(
                children: [
                  if (_radios.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      child: Row(
                        children: [
                          Text('推荐电台',
                              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Text('${_radios.length} 个',
                              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    ..._buildRadioList(),
                    const SizedBox(height: 24),
                  ],
                ],
              );

    return ResponsiveLayoutBuilder(
      mobile: (_) => Scaffold(
        appBar: AppBar(title: const Text('电台')),
        body: bodyContent,
      ),
      desktop: (_) => DesktopRouteWrapper(
        title: 'FM电台',
        maxWidth: 600,
        child: bodyContent,
      ),
    );
  }

  // ────────── 推荐电台 ──────────
  List<Widget> _buildRadioList() {
    final cs = Theme.of(context).colorScheme;
    return List.generate(_radios.length, (i) {
      final radio = _radios[i];
      final name = radio.name;
      final desc = radio.description ?? '';
      final img = _coverUrl(radio);
      final fmid = radio.id;
      final isExpanded = _selectedFmid == fmid;

      return Column(
        children: [
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: img.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: img,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              Icon(Icons.radio, color: cs.onSurfaceVariant, size: 24),
                        )
                      : Icon(Icons.radio, color: cs.onSurfaceVariant, size: 24),
                ),
              ),
              title: Text(name, maxLines: 1, style: const TextStyle(fontSize: 14)),
              subtitle: desc.isNotEmpty
                  ? Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))
                  : null,
              trailing: AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_more, size: 20),
              ),
              onTap: () => _onRadioTap(radio),
            ),
          ),
          if (isExpanded)
            _loadingSongs
                ? const Padding(
                    padding: EdgeInsets.all(16), child: CircularProgressIndicator())
                : _fmSongs.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16), child: Text('暂无歌曲'))
                    : Container(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        height: 200,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.builder(
                          itemCount: _fmSongs.length,
                          itemBuilder: (_, j) {
                            final song = _fmSongs[j];
                            return ListTile(
                              leading: const Icon(Icons.music_note),
                              title: Text(song.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(song.artistDisplay,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              onTap: () => _playSong(song),
                            );
                          },
                        ),
                      ),
        ],
      );
    });
  }

  String _coverUrl(RadioStation radio) {
    final url = radio.coverUrl ?? '';
    if (url.isNotEmpty) return url.replaceAll('{size}', '240');
    return '';
  }
}

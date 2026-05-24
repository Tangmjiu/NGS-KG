import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
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
  List<Map<String, dynamic>> _yuekuFm = [];
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
    await Future.wait([_loadFmRadios(), _loadYuekuFm()]);
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

  Future<void> _loadYuekuFm() async {
    try {
      final list = await _musicService.getYuekuRadio();
      if (mounted) setState(() => _yuekuFm = list);
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
    final player = context.read<PlayerProvider>();
    final fmid = _selectedFmid;
    if (fmid == null) return;
    player.playlistEndProvider = () => _musicService.getFmSongs(fmid);
    player.playSong(song, playlist: _fmSongs);
  }

  /// 从乐库电台数据中提取 fmid
  int _extractYuekuFmid(Map<String, dynamic> fm) {
    return fm['fmid'] as int? ??
        fm['id'] as int? ??
        fm['radio_id'] as int? ??
        0;
  }

  /// 提取名称
  String _extractYuekuName(Map<String, dynamic> fm) {
    return fm['name'] as String? ??
        fm['title'] as String? ??
        fm['fmname'] as String? ??
        '';
  }

  /// 提取封面图
  String _extractYuekuImg(Map<String, dynamic> fm) {
    final raw = fm['imgurl'] as String? ??
        fm['img'] as String? ??
        fm['cover'] as String? ??
        fm['banner'] as String? ??
        '';
    if (raw.isEmpty) return '';
    return raw.replaceAll('{size}', '480');
  }

  void _onYuekuTap(Map<String, dynamic> fm) async {
    final fmid = _extractYuekuFmid(fm);
    if (fmid <= 0) return;

    setState(() {
      _selectedFmid = fmid;
      _fmSongs = [];
      _loadingSongs = true;
    });

    try {
      final songs = await _musicService.getFmSongs(fmid);
      if (mounted) setState(() => _fmSongs = songs);
    } catch (e, s) {
      Log.e('fm_screen', 'error', e, s);
    }
    if (mounted) setState(() => _loadingSongs = false);
  }

  // ────────── 渐变色方案 ──────────
  static const _yuekuGradients = [
    [Color(0xFF6C3CE1), Color(0xFF9B59B6)],
    [Color(0xFFE74C3C), Color(0xFFF39C12)],
    [Color(0xFF1ABC9C), Color(0xFF3498DB)],
    [Color(0xFFE91E63), Color(0xFFFF5722)],
    [Color(0xFF00BCD4), Color(0xFF3F51B5)],
    [Color(0xFFFF6F00), Color(0xFFFFA000)],
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('电台')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _radios.isEmpty && _yuekuFm.isEmpty
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
                    if (_yuekuFm.isNotEmpty) _buildYuekuFmSection(cs, tt),
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
                ),
    );
  }

  // ────────── 乐库电台 ──────────
  Widget _buildYuekuFmSection(ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)]),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.radio, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text('乐库电台', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _yuekuFm.length + 1, // +1 for "all" entry
            itemBuilder: (_, i) {
              if (i == 0) return _buildYuekuEntryCard(cs, tt);
              final fm = _yuekuFm[i - 1];
              return _buildYuekuFmCard(fm, i - 1, cs, tt);
            },
          ),
        ),
        if (_selectedFmid != null && _selectedFmid! > 0) _buildExpandedSongs(cs),
      ],
    );
  }

  /// 乐库电台入口卡片
  Widget _buildYuekuEntryCard(ColorScheme cs, TextTheme tt) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D2D2D), Color(0xFF1A1A2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // 收起展开的歌曲列表
            if (_selectedFmid != null) setState(() => _selectedFmid = null);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.radio, color: cs.primary, size: 28),
              ),
              const SizedBox(height: 8),
              Text('乐库电台',
                  style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${_yuekuFm.length} 个',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  /// 单个乐库电台卡片
  Widget _buildYuekuFmCard(Map<String, dynamic> fm, int index, ColorScheme cs, TextTheme tt) {
    final name = _extractYuekuName(fm);
    final img = _extractYuekuImg(fm);
    final gradient = _yuekuGradients[index % _yuekuGradients.length];
    final fmid = _extractYuekuFmid(fm);
    final isExpanded = _selectedFmid == fmid;

    return GestureDetector(
      onTap: () => _onYuekuTap(fm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: isExpanded ? 115 : 100,
        margin: EdgeInsets.only(right: isExpanded ? 8 : 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withValues(alpha: isExpanded ? 0.4 : 0.2),
              blurRadius: isExpanded ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 渐变背景
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // 封面图
              if (img.isNotEmpty)
                Opacity(
                  opacity: 0.4,
                  child: CachedNetworkImage(
                    imageUrl: img,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              // 文字
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          )),
                      if (isExpanded) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.play_circle_fill,
                                color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            const Text('播放',
                                style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // 选中指示
              if (isExpanded)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 展开的歌曲列表
  Widget _buildExpandedSongs(ColorScheme cs) {
    if (_loadingSongs) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 120,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_fmSongs.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text('暂无歌曲', style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Icon(Icons.queue_music, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('${_fmSongs.length} 首歌曲',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    if (_fmSongs.isNotEmpty) {
                      final player = context.read<PlayerProvider>();
                      final fmid = _selectedFmid;
                      if (fmid != null) {
                        player.playlistEndProvider =
                            () => _musicService.getFmSongs(fmid);
                      }
                      player.playSong(_fmSongs.first, playlist: _fmSongs);
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('播放全部', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: (_fmSongs.length * 56.0).clamp(56.0, 280.0),
            child: ListView.builder(
              itemCount: _fmSongs.length,
              itemBuilder: (_, j) {
                final song = _fmSongs[j];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: cs.primaryContainer.withValues(alpha: 0.4),
                    child: Text('${j + 1}',
                        style: TextStyle(fontSize: 11, color: cs.primary)),
                  ),
                  title: Text(song.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text(song.artistDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  onTap: () => _playSong(song),
                );
              },
            ),
          ),
        ],
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

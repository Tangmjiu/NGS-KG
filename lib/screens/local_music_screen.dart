import 'dart:io' show File, Platform;
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/local_music_provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../navidrome/navidrome_provider.dart';
import '../navidrome/navidrome_login_screen.dart';
import '../navidrome/navidrome_screen.dart';
import '../utils/logger.dart';
import '../widgets/list_bottom_spacer.dart';

class LocalMusicScreen extends StatefulWidget {
  const LocalMusicScreen({super.key});

  @override
  State<LocalMusicScreen> createState() => _LocalMusicScreenState();
}

class _LocalMusicScreenState extends State<LocalMusicScreen>
    with TickerProviderStateMixin {
  late final TabController _tabCtrl;
  late final TabController _innerTabCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _allSongsScrollCtrl = ScrollController();
  bool _permissionDenied = false;
  int _innerTabIndex = 0;
  String? _lastScrolledHighlight;
  final Map<int, Set<String>> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _innerTabCtrl = TabController(length: 4, vsync: this);
    _innerTabCtrl.addListener(_onInnerTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initScan();
    });
  }

  void _onInnerTabChanged() {
    final index = _innerTabCtrl.index;
    if (index == _innerTabIndex) return;
    setState(() => _innerTabIndex = index);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _innerTabCtrl.removeListener(_onInnerTabChanged);
    _innerTabCtrl.dispose();
    _searchCtrl.dispose();
    _allSongsScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _initScan() async {
    if (!mounted) return;
    if (Platform.isAndroid) {
      final status = await Permission.audio.status;
      if (!status.isGranted) {
        final result = await Permission.audio.request();
        if (!result.isGranted && mounted) {
          setState(() => _permissionDenied = true);
          return;
        }
      }
    }
    _permissionDenied = false;
    final localProv = context.read<LocalMusicProvider>();
    if (!localProv.scanned && !localProv.isScanning) {
      localProv.scanMusic();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('本地音乐'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: '本地文件'),
            Tab(text: 'Navidrome'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildLocalTab(),
          _buildNavidromeTab(),
        ],
      ),
    );
  }

  // ── Local music tab ──

  Widget _buildLocalTab() {
    if (_permissionDenied) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 80, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            const Text('需要存储权限才能扫描本地音乐'),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () {
                setState(() => _permissionDenied = false);
                _initScan();
              },
              child: const Text('重新请求权限'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: Platform.isAndroid ? openAppSettings : null,
              child: const Text('去设置开启'),
            ),
          ],
        ),
      );
    }

    return Consumer<LocalMusicProvider>(
      builder: (context, prov, _) {
        if (prov.isScanning && prov.songs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (prov.songs.isEmpty && !prov.isScanning) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.music_note, size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(prov.status,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                Text('请添加包含音乐文件的文件夹',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 20),
                FilledButton.tonal(
                  onPressed: () => _pickDirectory(prov),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.create_new_folder_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('选择音乐文件夹'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  onPressed: () => prov.refreshLibrary(),
                  label: const Text('重新扫描默认位置'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            _buildToolbar(prov),
            _buildInnerTabBar(),
            Expanded(
              child: TabBarView(
                controller: _innerTabCtrl,
                // 不在构建 TabBarView 时提前计算所有分组。
                children: List.generate(4, (index) => Builder(
                  builder: (_) {
                    if (index != _innerTabIndex) return const SizedBox.shrink();
                    return switch (index) {
                      0 => _buildAllSongsTab(prov),
                      1 => _buildGroupedTab(
                          prov: prov,
                          entries: prov.groupedByAlbum(),
                          tabIndex: index,
                          emptyIcon: Icons.album,
                          emptyLabel: '专辑',
                        ),
                      2 => _buildGroupedTab(
                          prov: prov,
                          entries: prov.groupedByArtist(),
                          tabIndex: index,
                          emptyIcon: Icons.person,
                          emptyLabel: '歌手',
                        ),
                      _ => _buildGroupedTab(
                          prov: prov,
                          entries: prov.groupedByFolder(),
                          tabIndex: index,
                          emptyIcon: Icons.folder_outlined,
                          emptyLabel: '文件夹',
                        ),
                    };
                  },
                )),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Inner tab bar (全部歌曲 / 专辑 / 歌手 / 文件夹) ──

  Widget _buildInnerTabBar() {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      child: TabBar(
        controller: _innerTabCtrl,
        tabAlignment: TabAlignment.fill,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
        unselectedLabelStyle: Theme.of(context).textTheme.labelLarge,
        tabs: const [
          Tab(
            text: '全部歌曲',
            icon: Icon(Icons.music_note, size: 18),
          ),
          Tab(
            text: '专辑',
            icon: Icon(Icons.album, size: 18),
          ),
          Tab(
            text: '歌手',
            icon: Icon(Icons.person, size: 18),
          ),
          Tab(
            text: '文件夹',
            icon: Icon(Icons.folder, size: 18),
          ),
        ],
      ),
    );
  }

  // ── "全部歌曲" tab — flat list with staggered animation ──

  Widget _buildAllSongsTab(LocalMusicProvider prov) {
    final songs = prov.songs;
    final highlightPath = prov.highlightedFilePath;

    // 同一高亮只定位一次，避免通知或元数据更新反复打断用户滚动。
    if (highlightPath == null) _lastScrolledHighlight = null;
    if (highlightPath != null && highlightPath != _lastScrolledHighlight) {
      final idx = songs.indexWhere((s) => s.filePath == highlightPath);
      if (idx >= 0) {
        _lastScrolledHighlight = highlightPath;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_allSongsScrollCtrl.hasClients ||
              prov.highlightedFilePath != highlightPath) return;
          const itemHeight = 72.0;
          final offset = (idx * itemHeight)
              .clamp(0.0, _allSongsScrollCtrl.position.maxScrollExtent);
          _allSongsScrollCtrl.animateTo(
            offset,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        });
      }
    }

    return ListView.builder(
      controller: _allSongsScrollCtrl,
      itemCount: songs.length + 1,
      itemBuilder: (_, i) {
        if (i == songs.length) {
          return const ListBottomSpacer(isHome: false, showText: false);
        }
        final song = songs[i];
        final isHighlighted = song.filePath == highlightPath;
        return M3StaggeredFadeIn(
          index: i,
          child: _buildSongTile(song, prov, isHighlighted: isHighlighted),
        );
      },
    );
  }

  // ── Grouped tabs (专辑 / 歌手 / 文件夹) ──

  Widget _buildGroupedTab({
    required LocalMusicProvider prov,
    required List<LocalGroupEntry> entries,
    required int tabIndex,
    required IconData emptyIcon,
    required String emptyLabel,
  }) {
    if (entries.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('暂无$emptyLabel',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    final expanded = _expandedGroups.putIfAbsent(tabIndex, () => <String>{});
    // 只记录每组起始索引，不创建展开分组中所有歌曲的 Widget。
    final starts = <int>[];
    var rowCount = 0;
    for (final entry in entries) {
      starts.add(rowCount);
      rowCount += 1 + (expanded.contains(entry.title) ? entry.songs.length : 0);
    }

    return ListView.builder(
      key: PageStorageKey('local-groups-$tabIndex'),
      itemCount: rowCount + 1,
      itemBuilder: (_, i) {
        if (i == rowCount) {
          return const ListBottomSpacer(isHome: false, showText: false);
        }
        var low = 0;
        var high = starts.length - 1;
        while (low < high) {
          final mid = (low + high + 1) ~/ 2;
          if (starts[mid] <= i) {
            low = mid;
          } else {
            high = mid - 1;
          }
        }
        final entry = entries[low];
        final songIndex = i - starts[low] - 1;
        if (songIndex < 0) {
          final isExpanded = expanded.contains(entry.title);
          return _buildGroupTile(entry, isExpanded: isExpanded, onTap: () {
            setState(() {
              if (isExpanded) {
                expanded.remove(entry.title);
              } else {
                expanded.add(entry.title);
              }
            });
          });
        }
        final song = entry.songs[songIndex];
        return Padding(
          key: ValueKey((tabIndex, entry.title, song.filePath)),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: _buildSongTile(song, prov),
        );
      },
    );
  }

  Widget _buildGroupTile(LocalGroupEntry entry, {
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey(entry.title),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: cs.surfaceContainerLow,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: AppShape.md),
      child: ListTile(
        shape: const RoundedRectangleBorder(borderRadius: AppShape.md),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: _buildCoverAvatar(entry.thumbnail, cs),
        title: Text(
          entry.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        subtitle: Text(
          '${entry.count} 首歌曲',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
        ),
        trailing: AnimatedRotation(
          turns: isExpanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 200),
          child: const Icon(Icons.expand_more),
        ),
        onTap: onTap,
      ),
    );
  }

  // ── Cover avatar: local files use MD3E music note fallback ──

  Widget _buildCoverAvatar(String? coverUrl, ColorScheme cs) {
    final hasCover = coverUrl != null && coverUrl.isNotEmpty;
    ImageProvider? image;
    if (hasCover) {
      if (coverUrl.startsWith('file:') || coverUrl.startsWith('/')) {
        final path = coverUrl.startsWith('file:')
            ? Uri.parse(coverUrl).toFilePath()
            : coverUrl;
        image = FileImage(File(path));
      } else {
        image = NetworkImage(coverUrl);
      }
      final pixels = (40 * MediaQuery.devicePixelRatioOf(context)).ceil();
      image = ResizeImage(image, width: pixels, height: pixels,
          policy: ResizeImagePolicy.fit);
    }
    return CircleAvatar(
      backgroundColor: cs.surfaceContainerHighest,
      backgroundImage: image,
      child: hasCover
          ? null
          : Icon(Icons.music_note_outlined, size: 22, color: cs.primary),
    );
  }

  // ── Shared song list tile (used in both flat and grouped views) ──

  Widget _buildSongTile(Song song, LocalMusicProvider prov, {bool isHighlighted = false}) {
    return Selector<PlayerProvider, ({bool isCurrent, bool isPlaying})>(
      selector: (_, player) {
        // 本地 ID 可随 MediaStore 重扫变化，路径才是稳定身份。
        final isCurrent = song.filePath != null &&
            song.filePath == player.currentSong?.filePath;
        return (isCurrent: isCurrent, isPlaying: isCurrent && player.isPlaying);
      },
      builder: (context, playback, _) {
        final cs = Theme.of(context).colorScheme;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: isHighlighted
              ? BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: ListTile(
            leading: _buildCoverAvatar(song.albumCoverUrl, cs),
            title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${song.artists.join(", ")}${song.albumName != null ? " · ${song.albumName}" : ""}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            trailing: playback.isCurrent
                ? Icon(playback.isPlaying ? Icons.equalizer : Icons.pause,
                    color: cs.primary)
                : IconButton(
                    icon: Icon(Icons.more_vert,
                        color: cs.onSurfaceVariant, size: 20),
                    onPressed: () => _showSongMenu(song, prov),
                  ),
            onTap: () async {
              final player = context.read<PlayerProvider>();
              prov.clearHighlight();
              await prov.loadDeferredMetadata(song);
              if (!mounted) return;
              final playlist = prov.songs;
              final updatedSong = playlist.firstWhere(
                (s) => s.filePath == song.filePath,
                orElse: () => song,
              );
              player.playSong(updatedSong,
                  playlist: playlist.contains(updatedSong)
                      ? playlist
                      : [updatedSong]);
            },
          ),
        );
      },
    );
  }

  /// 长按或点击更多时弹出操作菜单
  void _showSongMenu(Song song, LocalMusicProvider prov) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖拽指示条
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // 歌曲信息
              Row(
                children: [
                  _buildCoverAvatar(song.albumCoverUrl, cs),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(song.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600)),
                        if (song.artists.isNotEmpty)
                          Text(song.artists.join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              // 从列表移除
              ListTile(
                leading: Icon(Icons.playlist_remove, color: cs.onSurfaceVariant),
                title: const Text('从列表中移除'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteDialog(song, prov);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// M3E 风格删除确认弹窗
  Future<void> _showDeleteDialog(Song song, LocalMusicProvider prov) async {
    final cs = Theme.of(context).colorScheme;
    bool deleteFile = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            backgroundColor: cs.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题行
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.delete_outline,
                            color: cs.onErrorContainer, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Text('移除歌曲',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 歌曲名
                  Text(
                    song.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: cs.onSurface),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 20),
                  // 同时删除本地文件 复选框
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: deleteFile
                          ? cs.errorContainer.withValues(alpha: 0.3)
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: CheckboxListTile(
                      value: deleteFile,
                      onChanged: (v) => setState(() => deleteFile = v ?? false),
                      title: const Text('同时删除本地文件'),
                      subtitle: Text(
                        '此操作不可撤销',
                        style: TextStyle(
                            color: deleteFile ? cs.error : cs.onSurfaceVariant,
                            fontSize: 12),
                      ),
                      activeColor: cs.error,
                      checkColor: cs.onError,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 按钮行
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: TextButton.styleFrom(
                            foregroundColor: cs.onSurfaceVariant),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.error,
                          foregroundColor: cs.onError,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('移除'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (confirmed != true || !mounted) return;

    if (deleteFile) {
      final ok = await prov.deleteLocalFile(song);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? '已删除文件' : '删除失败，请检查权限'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      await prov.removeSong(song);
    }
  }

  // ── Toolbar ──

  Widget _buildToolbar(LocalMusicProvider prov) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Status text
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(prov.status,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant)),
          ),
          // Search field
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '搜索歌曲、歌手、专辑...',
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18, color: cs.onSurfaceVariant),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
                        onPressed: () {
                          _searchCtrl.clear();
                          prov.search('');
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: AppShape.sm,
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
              ),
              onChanged: (v) {
                prov.search(v);
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 8),
          // Sort dropdown
          PopupMenuButton<String>(
            icon: Icon(Icons.sort, size: 20, color: cs.onSurfaceVariant),
            tooltip: '排序',
            onSelected: prov.sortBy,
            itemBuilder: (_) => [
              _sortItem('歌名', 'title', prov),
              _sortItem('歌手', 'artist', prov),
              _sortItem('专辑', 'album', prov),
              _sortItem('时长', 'duration', prov),
            ],
          ),
          // Add folder
          IconButton(
            icon: Icon(Icons.create_new_folder_outlined, size: 20,
                color: cs.onSurfaceVariant),
            tooltip: '添加音乐文件夹',
            onPressed: prov.isScanning ? null : () => _pickDirectory(prov),
          ),
          // Manage folders
          IconButton(
            icon: Icon(Icons.folder_outlined, size: 20,
                color: cs.onSurfaceVariant),
            tooltip: '管理扫描文件夹',
            onPressed: prov.isScanning ? null : () => _showDirManager(prov),
          ),
          // Refresh
          IconButton(
            icon: prov.isScanning
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.onSurfaceVariant))
                : Icon(Icons.refresh, size: 20, color: cs.onSurfaceVariant),
            tooltip: '重新扫描',
            onPressed: prov.isScanning ? null : () => prov.refreshLibrary(),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _sortItem(
      String label, String field, LocalMusicProvider prov) {
    final isSelected = prov.sortField == field;
    final arrow = isSelected
        ? (prov.sortAscending ? ' ↑' : ' ↓')
        : '';
    return PopupMenuItem(
      value: field,
      child: Text('$label$arrow',
          style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
    );
  }

  // ── Directory management ──

  Future<void> _pickDirectory(LocalMusicProvider prov) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择音乐文件夹',
    );
    if (result != null && mounted) {
      await prov.addSearchDir(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加扫描目录: $result')),
        );
      }
    }
  }

  Future<void> _showDirManager(LocalMusicProvider prov) async {
    final dirs = await prov.getSearchDirs();
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;

    showM3Dialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('扫描文件夹'),
        content: SizedBox(
          width: 400,
          child: dirs.isEmpty
              ? Text('暂无自定义文件夹',
                  style: TextStyle(color: cs.onSurfaceVariant))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: dirs.length,
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    leading: Icon(Icons.folder, size: 20,
                        color: cs.onSurfaceVariant),
                    title: Text(dirs[i],
                        style: Theme.of(context).textTheme.bodyMedium),
                    trailing: IconButton(
                      icon: Icon(Icons.remove_circle_outline, size: 18,
                          color: cs.error),
                      tooltip: '移除',
                      onPressed: () {
                        Navigator.pop(ctx);
                        prov.removeSearchDir(dirs[i]);
                      },
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.pop(ctx);
              _pickDirectory(prov);
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 18),
                SizedBox(width: 8),
                Text('添加文件夹'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Navidrome tab ──

  Widget _buildNavidromeTab() {
    return Consumer<NavidromeProvider>(
      builder: (context, navProv, _) {
        if (navProv.connected) {
          return const NavidromeScreen();
        }
        // 未连接时显示引导按钮，点按后以全屏路由打开登录页（自带 Scaffold+AppBar）
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_find,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('未连接到 Navidrome 服务器',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Text('Navidrome 是开源的自托管音乐服务器',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NavidromeLoginScreen()),
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link),
                    SizedBox(width: 8),
                    Text('连接服务器'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

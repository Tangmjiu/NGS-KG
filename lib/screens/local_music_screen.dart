// SPDX-License-Identifier: MIT
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../ui/app_ui.dart';
import '../ui/components/cover_art.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/local_music_provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../navidrome/navidrome_provider.dart';
import '../navidrome/navidrome_login_screen.dart';
import '../navidrome/navidrome_screen.dart';
import '../ui/components/player_bottom_padding.dart';

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
    if (!mounted) return;
    _permissionDenied = false;
    final localProv = context.read<LocalMusicProvider>();
    if (!localProv.scanned && !localProv.isScanning) {
      localProv.scanMusic();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AppPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppPageHeader(
                title: '本地与云端',
                subtitle: '收藏在设备里，也连接你的私人音乐库',
                showBack: true,
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.pagePadding),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(tokens.controlRadius),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(tokens.controlRadius),
                    ),
                    labelColor: cs.onSecondaryContainer,
                    tabs: const [Tab(text: '本地文件'), Tab(text: 'Navidrome')],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [_buildLocalTab(), _buildNavidromeTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Local music tab ──

  Widget _buildLocalTab() {
    if (_permissionDenied) {
      return AppEmptyState(
        icon: Icons.folder_off_outlined,
        title: '允许访问音乐文件',
        message: '授予音频访问权限后，即可扫描和播放设备中的音乐。',
        action: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: () {
                setState(() => _permissionDenied = false);
                _initScan();
              },
              child: const Text('授予权限'),
            ),
            if (Platform.isAndroid)
              const TextButton(
                  onPressed: openAppSettings, child: const Text('打开应用设置')),
          ],
        ),
      );
    }

    return Consumer<LocalMusicProvider>(
      builder: (context, prov, _) => Column(
        children: [
          _buildToolbar(prov),
          _buildInnerTabBar(),
          if (prov.isScanning) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: prov.songs.isEmpty
                ? _buildEmptyLibrary(prov)
                : TabBarView(
                    controller: _innerTabCtrl,
                    // 仅计算当前分类，分组中的歌曲仍由列表逐项构建。
                    children: List.generate(
                        4,
                        (index) => Builder(
                              builder: (_) {
                                if (index != _innerTabIndex) {
                                  return const SizedBox.shrink();
                                }
                                return switch (index) {
                                  0 => _buildAllSongsTab(prov),
                                  1 => _buildGroupedTab(
                                      prov: prov,
                                      entries: prov.groupedByAlbum(),
                                      tabIndex: index,
                                      emptyIcon: Icons.album_outlined,
                                      emptyLabel: '专辑',
                                    ),
                                  2 => _buildGroupedTab(
                                      prov: prov,
                                      entries: prov.groupedByArtist(),
                                      tabIndex: index,
                                      emptyIcon: Icons.person_outline_rounded,
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
      ),
    );
  }

  Widget _buildEmptyLibrary(LocalMusicProvider prov) {
    if (prov.isScanning) {
      return const AppEmptyState(
        icon: Icons.manage_search_rounded,
        title: '正在寻找音乐',
        message: '扫描完成后，歌曲会显示在这里。',
      );
    }
    if (_searchCtrl.text.isNotEmpty) {
      return AppEmptyState(
        icon: Icons.search_off_rounded,
        title: '未找到本地歌曲',
        message: '试试其他歌曲、歌手或专辑名称。',
        action: TextButton(
          onPressed: () => _clearSearch(prov),
          child: const Text('清空搜索'),
        ),
      );
    }
    return AppEmptyState(
      icon: Icons.library_music_outlined,
      title: '还没有本地音乐',
      message: '添加音乐文件夹，让喜欢的声音随时相伴。',
      action: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () => _pickDirectory(prov),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('添加音乐文件夹'),
          ),
          TextButton(
            onPressed: prov.refreshLibrary,
            child: const Text('扫描默认位置'),
          ),
        ],
      ),
    );
  }

  void _clearSearch(LocalMusicProvider prov) {
    _searchCtrl.clear();
    prov.search('');
    setState(() {});
  }

  // ── Inner tab bar (全部歌曲 / 专辑 / 歌手 / 文件夹) ──

  Widget _buildInnerTabBar() => Padding(
        padding: EdgeInsets.symmetric(
            horizontal: AppThemeTokens.of(context).pagePadding),
        child: TabBar(
          controller: _innerTabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: '全部歌曲'),
            Tab(text: '专辑'),
            Tab(text: '歌手'),
            Tab(text: '文件夹'),
          ],
        ),
      );

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
          if (!mounted ||
              !_allSongsScrollCtrl.hasClients ||
              prov.highlightedFilePath != highlightPath) {
            return;
          }
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
          return const PlayerBottomPadding(showLabel: false);
        }
        final song = songs[i];
        final isHighlighted = song.filePath == highlightPath;
        return StaggeredEntrance(
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
      return AppEmptyState(icon: emptyIcon, title: '暂无$emptyLabel');
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
          return const PlayerBottomPadding(showLabel: false);
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

  Widget _buildGroupTile(
    LocalGroupEntry entry, {
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    final tokens = AppThemeTokens.of(context);
    return Padding(
      key: ValueKey(entry.title),
      padding:
          EdgeInsets.symmetric(horizontal: tokens.pagePadding, vertical: 6),
      child: AppSurface(
        padding: EdgeInsets.zero,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: _buildCoverAvatar(entry.thumbnail),
          title: Text(entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text('${entry.count} 首歌曲'),
          trailing: AnimatedRotation(
            turns: isExpanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.expand_more_rounded),
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildCoverAvatar(String? coverUrl) => CoverArt(
        url: coverUrl,
        size: 44,
        borderRadius: AppThemeTokens.of(context).controlRadius,
      );

  // ── Shared song list tile (used in both flat and grouped views) ──

  Widget _buildSongTile(Song song, LocalMusicProvider prov,
      {bool isHighlighted = false}) {
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
            leading: CoverArt(
              url: song.albumCoverUrl,
              coverData: song.coverData,
              size: 44,
              borderRadius: AppThemeTokens.of(context).controlRadius,
            ),
            title:
                Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
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
            onLongPress: () => _showSongMenu(song, prov),
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
                  CoverArt(
                    url: song.albumCoverUrl,
                    coverData: song.coverData,
                    size: 44,
                    borderRadius: AppThemeTokens.of(context).controlRadius,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(song.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600)),
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
                leading:
                    Icon(Icons.playlist_remove, color: cs.onSurfaceVariant),
                title: const Text('从列表中移除'),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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

  /// 移除歌曲前确认是否同时删除文件
  Future<void> _showDeleteDialog(Song song, LocalMusicProvider prov) async {
    final cs = Theme.of(context).colorScheme;
    bool deleteFile = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 歌曲名
                  Text(
                    song.name,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: cs.onSurface),
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
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: tokens.pagePadding, vertical: 8),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '搜索本地歌曲、歌手或专辑',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空搜索',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => _clearSearch(prov),
                    ),
              filled: true,
              fillColor: cs.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.controlRadius),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.controlRadius),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (query) {
              prov.search(query);
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: Text(prov.status,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant))),
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort_rounded),
                tooltip: '排序',
                onSelected: prov.sortBy,
                itemBuilder: (_) => [
                  _sortItem('歌名', 'title', prov),
                  _sortItem('歌手', 'artist', prov),
                  _sortItem('专辑', 'album', prov),
                  _sortItem('时长', 'duration', prov),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.create_new_folder_outlined),
                tooltip: '添加音乐文件夹',
                onPressed: prov.isScanning ? null : () => _pickDirectory(prov),
              ),
              IconButton(
                icon: const Icon(Icons.folder_outlined),
                tooltip: '管理扫描文件夹',
                onPressed: prov.isScanning ? null : () => _showDirManager(prov),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: '重新扫描',
                onPressed: prov.isScanning ? null : prov.refreshLibrary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _sortItem(
      String label, String field, LocalMusicProvider prov) {
    final isSelected = prov.sortField == field;
    final arrow = isSelected ? (prov.sortAscending ? ' ↑' : ' ↓') : '';
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

    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('扫描文件夹'),
        content: SizedBox(
          width: 400,
          child: dirs.isEmpty
              ? Text('暂无自定义文件夹', style: TextStyle(color: cs.onSurfaceVariant))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: dirs.length,
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    leading: Icon(Icons.folder,
                        size: 20, color: cs.onSurfaceVariant),
                    title: Text(dirs[i],
                        style: Theme.of(context).textTheme.bodyMedium),
                    trailing: IconButton(
                      icon: Icon(Icons.remove_circle_outline,
                          size: 18, color: cs.error),
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

  Widget _buildNavidromeTab() => Consumer<NavidromeProvider>(
        builder: (context, navidrome, _) => navidrome.connected
            ? const NavidromeScreen()
            : AppEmptyState(
                icon: Icons.dns_outlined,
                title: '连接私人音乐库',
                message: '连接 Navidrome 服务器，在这里浏览和播放你的云端收藏。',
                action: FilledButton.icon(
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('连接服务器'),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NavidromeLoginScreen(),
                      )),
                ),
              ),
      );
}

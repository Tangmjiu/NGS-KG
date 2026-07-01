import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/local_music_provider.dart';
import '../providers/player_provider.dart';
import '../navidrome/navidrome_provider.dart';
import '../navidrome/navidrome_login_screen.dart';
import '../navidrome/navidrome_screen.dart';
import '../utils/logger.dart';

class LocalMusicScreen extends StatefulWidget {
  const LocalMusicScreen({super.key});

  @override
  State<LocalMusicScreen> createState() => _LocalMusicScreenState();
}

class _LocalMusicScreenState extends State<LocalMusicScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initScan();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
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
        if (prov.isScanning && prov.status == '正在扫描...') {
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
                    style: TextStyle(
                        fontSize: 13,
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
                  onPressed: () => prov.scanMusic(),
                  label: const Text('重新扫描默认位置'),
                ),
              ],
            ),
          );
        }

        final songs = prov.toSongList();

        return Column(
          children: [
            _buildToolbar(prov),
            Expanded(
              child: ListView.builder(
                itemCount: songs.length,
                itemBuilder: (_, i) {
                  final song = songs[i];
                  final currentSongId =
                      context.watch<PlayerProvider>().currentSong?.id;
                  final isPlaying = song.id == currentSongId;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      backgroundImage: song.coverImageProvider,
                    ),
                    title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${song.artists.join(", ")}${song.albumName != null ? " · ${song.albumName}" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    trailing: isPlaying
                        ? Icon(Icons.equalizer,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () async {
                      // 触发按需封面 + 歌词加载（非阻塞）
                      final matchingLocal = prov.songs.firstWhere(
                        (ls) => ls.filePath == song.filePath,
                        orElse: () => prov.songs.first,
                      );
                      prov.loadDeferredMetadata(matchingLocal);

                      final playlist = prov.toSongList();
                      context.read<PlayerProvider>().playSong(song, playlist: playlist);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

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
                  borderRadius: BorderRadius.circular(8),
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
            onPressed: prov.isScanning ? null : () => prov.scanMusic(),
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

    showDialog(
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
                        style: const TextStyle(fontSize: 13)),
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
                  style: TextStyle(
                      fontSize: 13,
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

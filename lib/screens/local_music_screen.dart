import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/local_music_provider.dart';
import '../providers/player_provider.dart';
import '../navidrome/navidrome_provider.dart';
import '../navidrome/navidrome_login_screen.dart';
import '../navidrome/navidrome_screen.dart';
import '../utils/responsive.dart';
import '../widgets/desktop_route_wrapper.dart';
import '../widgets/desktop_song_table.dart';
import '../widgets/local_cover_art.dart';
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
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    // Trigger scan on first load if not already scanned
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final localProv = context.read<LocalMusicProvider>();
      if (!localProv.scanned && !localProv.isScanning) {
        localProv.scanMusic();
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        // TabBar
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(text: '本地文件'),
              Tab(text: 'Navidrome'),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildLocalTab(),
              _buildNavidromeTab(),
            ],
          ),
        ),
      ],
    );

    return ResponsiveLayoutBuilder(
      mobile: (_) => Scaffold(
        appBar: AppBar(title: const Text('本地音乐')),
        body: content,
      ),
      desktop: (_) => DesktopRouteWrapper(
        title: '本地音乐',
        maxWidth: 1000,
        child: content,
      ),
    );
  }

  // ── Local music tab ──

  Widget _buildLocalTab() {
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
            // Search + sort + status bar
            _buildToolbar(prov),
            // Song table
            Expanded(
              child: DesktopSongTable(
                songs: songs,
                isLoading: prov.isScanning,
                emptyMessage: prov.status,
                currentSongId:
                    context.watch<PlayerProvider>().currentSong?.id,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar(LocalMusicProvider prov) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Status text
          if (!_showSearch)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(prov.status,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ),
          // Search field
          Expanded(
            child: _showSearch
                ? TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: '搜索歌曲、歌手、专辑...',
                      isDense: true,
                      prefixIcon:
                          Icon(Icons.search, size: 18, color: cs.onSurfaceVariant),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
                        onPressed: () {
                          _searchCtrl.clear();
                          prov.search('');
                          setState(() => _showSearch = false);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                    ),
                    style: tt.bodySmall,
                    onChanged: prov.search,
                  )
                : const SizedBox.shrink(),
          ),
          if (!_showSearch)
            IconButton(
              icon: Icon(Icons.search, size: 20, color: cs.onSurfaceVariant),
              tooltip: '搜索',
              onPressed: () => setState(() => _showSearch = true),
            ),
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
                  showDialog(
                    context: context,
                    builder: (_) => const NavidromeLoginScreen(),
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

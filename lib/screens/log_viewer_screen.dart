import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _filterTag = TextEditingController();
  bool _autoScroll = true;
  bool _showDetail = false;
  String _levelFilter = '';
  String _tagFilter = '';

  @override
  void initState() {
    super.initState();
    Log.onEntry.addListener(_onNewEntry);
  }

  @override
  void dispose() {
    Log.onEntry.removeListener(_onNewEntry);
    _scroll.dispose();
    _filterTag.dispose();
    super.dispose();
  }

  void _onNewEntry() {
    if (!_autoScroll || !_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<LogEntry> get _filtered {
    var list = Log.entries;
    if (_levelFilter.isNotEmpty) {
      list = list.where((e) => e.level == _levelFilter).toList();
    }
    if (_tagFilter.isNotEmpty) {
      final lower = _tagFilter.toLowerCase();
      list = list.where((e) => e.tag.toLowerCase().contains(lower)).toList();
    }
    return list;
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'E':
        return Colors.redAccent;
      case 'W':
        return Colors.orangeAccent;
      case 'I':
        return Colors.lightGreenAccent;
      default:
        return Colors.grey;
    }
  }

  Future<void> _export() async {
    try {
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download/NGS-KG+_Logs');
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final ts = DateTime.now()
          .toString()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final file = File('${dir.path}/ngskg_log_$ts.txt');
      final content = Log.entries.map((e) => e.formatted).join('\n');
      await file.writeAsString(content);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('已导出: ${file.path}'),
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerLowest;
    return Scaffold(
      appBar: AppBar(
        title: const Text('输出日志'),
        actions: [
          IconButton(
            icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center),
            tooltip: '自动滚动',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: _showDetail ? '简洁模式' : '详细模式',
            onPressed: () => setState(() => _showDetail = !_showDetail),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: '导出日志',
            onPressed: _export,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: [
                _buildLevelChip('', 'ALL'),
                const SizedBox(width: 4),
                _buildLevelChip('E', 'ERR'),
                const SizedBox(width: 4),
                _buildLevelChip('W', 'WRN'),
                const SizedBox(width: 4),
                _buildLevelChip('I', 'INF'),
                const SizedBox(width: 4),
                _buildLevelChip('D', 'DBG'),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: TextField(
                      controller: _filterTag,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: '搜索 tag...',
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                      ),
                      onChanged: (v) => setState(() => _tagFilter = v),
                    ),
                  ),
                ),
                if (_filterTag.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _filterTag.clear();
                      setState(() => _tagFilter = '');
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Log list
          Expanded(
            child: ValueListenableBuilder<LogEntry?>(
              valueListenable: Log.onEntry,
              builder: (_, __, ___) {
                final entries = _filtered;
                if (entries.isEmpty) {
                  return const Center(child: Text('暂无日志'));
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  itemCount: entries.length,
                  itemExtent: _showDetail ? 64 : 24,
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    return _buildLogRow(e, bg);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelChip(String level, String label) {
    final selected = _levelFilter == level;
    return GestureDetector(
      onTap: () => setState(() => _levelFilter = level),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: selected ? _levelColor(level) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.grey,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.black : null,
          ),
        ),
      ),
    );
  }

  Widget _buildLogRow(LogEntry e, Color bg) {
    if (_showDetail) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: bg, width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(e.level, style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold,
                  color: _levelColor(e.level),
                )),
                const SizedBox(width: 4),
                Text('${_fmtTime(e.time)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(e.tag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(e.message, style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
            if (e.error != null)
              Text('${e.error}', style: TextStyle(fontSize: 10, color: Colors.red.shade300), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(e.level, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold,
            color: _levelColor(e.level),
          )),
          const SizedBox(width: 4),
          Text('${_fmtTime(e.time)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(width: 4),
          Text('[${e.tag}]', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          Expanded(child: Text(e.message, style: const TextStyle(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  String _fmtTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
  }
}

import 'package:flutter/material.dart';
import '../services/music_service.dart';

class SheetDetailScreen extends StatefulWidget {
  final int sheetId;
  final String? sheetName;

  const SheetDetailScreen({super.key, required this.sheetId, this.sheetName});

  @override
  State<SheetDetailScreen> createState() => _SheetDetailScreenState();
}

class _SheetDetailScreenState extends State<SheetDetailScreen> {
  final MusicService _musicService = MusicService();
  Map<String, dynamic>? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await _musicService.getSheetDetail(widget.sheetId);
      if (mounted) setState(() => _detail = detail);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.sheetName ?? '曲谱详情')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _detail == null
              ? const Center(child: Text('暂无数据'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_detail!['imgUrl'] != null || _detail!['coverImgUrl'] != null)
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _detail!['imgUrl'] as String? ?? _detail!['coverImgUrl'] as String? ?? '',
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 200, height: 200,
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.music_note, size: 64),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(_detail!['content'] as String? ?? _detail!['detail'] as String? ?? '暂无详情'),
                    ],
                  ),
                ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/music_service.dart';

class SheetCollectionDetailScreen extends StatefulWidget {
  final int id;
  final String? name;

  const SheetCollectionDetailScreen({super.key, required this.id, this.name});

  @override
  State<SheetCollectionDetailScreen> createState() => _SheetCollectionDetailScreenState();
}

class _SheetCollectionDetailScreenState extends State<SheetCollectionDetailScreen> {
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
      final detail = await _musicService.getSheetCollectionDetail(widget.id);
      if (mounted) setState(() => _detail = detail);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name ?? '曲谱合集')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _detail == null
              ? const Center(child: Text('暂无数据'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(_detail.toString()),
                ),
    );
  }
}

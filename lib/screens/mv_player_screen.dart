import 'package:flutter/material.dart';
import '../services/music_service.dart';

class MvPlayerScreen extends StatefulWidget {
  final String? hash;
  final String? name;

  const MvPlayerScreen({
    super.key,
    this.hash,
    this.name,
  });

  @override
  State<MvPlayerScreen> createState() => _MvPlayerScreenState();
}

class _MvPlayerScreenState extends State<MvPlayerScreen> {
  final _musicService = MusicService();

  String? _mvUrl;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMvUrl();
  }

  Future<void> _loadMvUrl() async {
    if (widget.hash == null) {
      setState(() {
        _error = '无法获取MV';
        _isLoading = false;
      });
      return;
    }
    try {
      final url = await _musicService.getMvUrl(widget.hash!);
      if (mounted) {
        setState(() {
          _mvUrl = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name ?? 'MV'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Center(
                  child: _mvUrl != null
                      ? const Text('MV播放器 (暂未实现)')
                      : const Text('无法播放'),
                ),
    );
  }
}
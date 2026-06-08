// MV 播放功能已暂停适配，代码保留供后续参考
/*
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
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

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMvUrl();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadMvUrl() async {
    final hash = widget.hash;
    if (hash == null) {
      setState(() {
        _error = '无法获取MV';
        _isLoading = false;
      });
      return;
    }
    try {
      final url = await _musicService.getMvUrl(hash);
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        setState(() {
          _error = '无法获取MV地址';
          _isLoading = false;
        });
        return;
      }
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoController!.initialize();
      if (!mounted) return;
      final vidCtrl = _videoController;
      if (vidCtrl == null) return;
      _chewieController = ChewieController(
        videoPlayerController: vidCtrl,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        placeholder: Container(color: Colors.black),
        materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).colorScheme.primary,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white12,
          handleColor: Theme.of(context).colorScheme.primary,
        ),
      );
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.name ?? 'MV', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
              : _chewieController != null && _videoController != null
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: Chewie(controller: _chewieController!),
                      ),
                    )
                  : const SizedBox.shrink(),
    );
  }
}
*/

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/music_service.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';

class CreatePlaylistDialog extends StatefulWidget {
  const CreatePlaylistDialog({super.key});

  @override
  State<CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建歌单'),
      content: TextField(
        controller: _nameCtrl,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '歌单名称',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: _saving ? null : _create,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('创建'),
        ),
      ],
    );
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await MusicService().createPlaylist(name);
      if (mounted) {
        Navigator.pop(context);
        context.read<PlaylistProvider>().fetchUserPlaylist(
          context.read<AuthProvider>().user?.userId,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败: $e')));
        setState(() => _saving = false);
      }
    }
  }
}

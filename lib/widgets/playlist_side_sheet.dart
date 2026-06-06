import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';

/// 弹出桌面端播放列表 Side Sheet（右侧覆盖层，360px 宽）
void showPlaylistSideSheet(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭播放列表',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, _, __) {
      return const _PlaylistSideSheet();
    },
    transitionBuilder: (context, animation, _, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        )),
        child: child,
      );
    },
  );
}

class _PlaylistSideSheet extends StatelessWidget {
  const _PlaylistSideSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 360,
          height: double.infinity,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(-4, 0),
              ),
            ],
          ),
          child: Consumer<PlayerProvider>(
            builder: (_, player, __) {
              return Column(
                children: [
                  // 标题栏
                  _header(context, player),
                  // 列表
                  Expanded(child: _list(context, player)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, PlayerProvider player) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text('播放列表',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('${player.playlist.length} 首',
              style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          if (player.playlist.isNotEmpty)
            TextButton(
              onPressed: () {
                player.clearPlaylist();
                Navigator.pop(context);
              },
              child: const Text('清空', style: TextStyle(fontSize: 13)),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, PlayerProvider player) {
    if (player.playlist.isEmpty) {
      return Center(
        child: Text('列表为空',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: player.playlist.length,
      itemBuilder: (_, i) {
        final s = player.playlist[i];
        final isCurrent = i == player.currentIndex;
        return ListTile(
          dense: true,
          leading: isCurrent
              ? Icon(Icons.play_arrow_rounded,
                  size: 20, color: Theme.of(context).colorScheme.primary)
              : SizedBox(
                  width: 20,
                  child: Text('${i + 1}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant))),
          title: Text(
            s.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              color: isCurrent
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
          subtitle: Text(
            s.artistDisplay,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          onTap: () {
            player.playIndex(i);
            Navigator.pop(context);
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../providers/player_provider.dart';

class PlayerControlsBar extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final PlayMode playMode;
  final VoidCallback onModeToggle;
  final VoidCallback onShowPlaylist;

  const PlayerControlsBar({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.playMode,
    required this.onModeToggle,
    required this.onShowPlaylist,
  });

  IconData _modeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.sequential:
        return Icons.repeat;
      case PlayMode.shuffle:
        return Icons.shuffle;
      case PlayMode.repeatOne:
        return Icons.repeat_one;
      case PlayMode.radio:
        return Icons.repeat; // fallback for radio mode
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // -- Play Mode --
        IconButton(
          icon: Icon(_modeIcon(playMode), size: 24, color: Colors.white70),
          onPressed: onModeToggle,
          splashRadius: 24,
          padding: EdgeInsets.zero,
        ),

        // -- Previous --
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 36, color: Colors.white),
          onPressed: onPrevious,
          splashRadius: 24,
          padding: EdgeInsets.zero,
        ),

        // -- Play / Pause --
        InkWell(
          onTap: onPlayPause,
          borderRadius: BorderRadius.circular(28),
          customBorder: const CircleBorder(),
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: _buildPlayPauseChild(),
            ),
          ),
        ),

        // -- Next --
        IconButton(
          icon: const Icon(Icons.skip_next, size: 36, color: Colors.white),
          onPressed: onNext,
          splashRadius: 24,
          padding: EdgeInsets.zero,
        ),

        // -- Playlist --
        IconButton(
          icon:
              const Icon(Icons.playlist_play, size: 24, color: Colors.white70),
          onPressed: onShowPlaylist,
          splashRadius: 24,
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildPlayPauseChild() {
    if (isLoading) {
      return SizedBox(
        key: const ValueKey('loading'),
        width: 28,
        height: 28,
        child: const CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Colors.black54,
        ),
      );
    }

    return Icon(
      key: ValueKey(isPlaying),
      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
      size: 32,
      color: Colors.black,
    );
  }
}

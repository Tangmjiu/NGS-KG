import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// Three-button player controls: previous, play/pause, next.
/// Mode toggle and playlist button have been moved to the bottom icon bar.
class PlayerControlsBar extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const PlayerControlsBar({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // -- Previous --
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 36, color: Colors.white),
          onPressed: onPrevious,
          splashRadius: 24,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
        ),

        const SizedBox(width: 8),

        // -- Play / Pause --
        InkWell(
          onTap: onPlayPause,
          borderRadius: AppShape.xl,
          customBorder: const CircleBorder(),
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.dShort4,
              switchInCurve: AppMotion.emphasized,
              switchOutCurve: AppMotion.emphasized,
              child: _buildPlayPauseChild(),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // -- Next --
        IconButton(
          icon: const Icon(Icons.skip_next, size: 36, color: Colors.white),
          onPressed: onNext,
          splashRadius: 24,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
        ),
      ],
    );
  }

  Widget _buildPlayPauseChild() {
    if (isLoading) {
      return const SizedBox(
        key: ValueKey('loading'),
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Colors.black54,
        ),
      );
    }

    return Icon(
      key: ValueKey(isPlaying),
      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
      size: 36,
      color: Colors.black87,
    );
  }
}

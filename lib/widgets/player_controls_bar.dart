import 'package:flutter/material.dart';

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
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // -- Previous --
        IconButton(
          icon: Icon(Icons.skip_previous, size: 36, color: cs.onSurface),
          onPressed: onPrevious,
          splashRadius: 24,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
        ),

        const SizedBox(width: 8),

        // -- Play / Pause --
        InkWell(
          onTap: onPlayPause,
          borderRadius: BorderRadius.circular(28),
          customBorder: const CircleBorder(),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.onSurface,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: _buildPlayPauseChild(cs),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // -- Next --
        IconButton(
          icon: Icon(Icons.skip_next, size: 36, color: cs.onSurface),
          onPressed: onNext,
          splashRadius: 24,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
        ),
      ],
    );
  }

  Widget _buildPlayPauseChild(ColorScheme cs) {
    if (isLoading) {
      return SizedBox(
        key: const ValueKey('loading'),
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: cs.surface,
        ),
      );
    }

    return Icon(
      key: ValueKey(isPlaying),
      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
      size: 36,
      color: cs.surface,
    );
  }
}

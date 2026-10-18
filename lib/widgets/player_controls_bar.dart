// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import '../ui/app_ui.dart';

/// Three-button player controls: previous, play/pause, next.
/// Mode toggle and playlist button have been moved to the bottom icon bar.
class PlayerControlsBar extends StatefulWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final String previousLabel;
  final IconData previousIcon;
  final VoidCallback onNext;

  const PlayerControlsBar({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    required this.onPlayPause,
    required this.onPrevious,
    this.previousLabel = '上一首',
    this.previousIcon = Icons.skip_previous,
    required this.onNext,
  });

  @override
  State<PlayerControlsBar> createState() => _PlayerControlsBarState();
}

class _PlayerControlsBarState extends State<PlayerControlsBar>
    with WidgetsBindingObserver {
  bool _foreground = true;
  bool _systemReduceMotion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    _systemReduceMotion = features.disableAnimations || features.reduceMotion;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _foreground = state == AppLifecycleState.resumed);
  }

  @override
  void didChangeAccessibilityFeatures() {
    setState(() {
      final features =
          WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
      _systemReduceMotion = features.disableAnimations || features.reduceMotion;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = _foreground &&
        !_systemReduceMotion &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    final playLabel = widget.isPlaying ? '暂停' : '播放';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // -- Previous --
        IconButton(
          icon: Icon(widget.previousIcon, size: 36, color: Colors.white),
          onPressed: widget.onPrevious,
          tooltip: widget.previousLabel,
          visualDensity: VisualDensity.standard,
          splashRadius: 24,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
        ),

        const SizedBox(width: 8),

        // -- Play / Pause --
        Semantics(
          button: true,
          label: playLabel,
          value: widget.isLoading ? '正在加载' : null,
          onTap: widget.onPlayPause,
          child: ExcludeSemantics(
            child: Tooltip(
              message: playLabel,
              child: InkWell(
                excludeFromSemantics: true,
                onTap: widget.onPlayPause,
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
                    duration: animate ? AppMotion.dShort4 : Duration.zero,
                    switchInCurve: AppMotion.emphasized,
                    switchOutCurve: AppMotion.emphasized,
                    child: _buildPlayPauseChild(animate),
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // -- Next --
        IconButton(
          icon: const Icon(Icons.skip_next, size: 36, color: Colors.white),
          onPressed: widget.onNext,
          tooltip: '下一首',
          visualDensity: VisualDensity.standard,
          splashRadius: 24,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
        ),
      ],
    );
  }

  Widget _buildPlayPauseChild(bool animate) {
    if (widget.isLoading) {
      return SizedBox(
        key: const ValueKey('loading'),
        width: 28,
        height: 28,
        child: animate
            ? const CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.black54,
              )
            : const Icon(Icons.hourglass_top_rounded,
                size: 28, color: Colors.black54),
      );
    }

    return Icon(
      key: ValueKey(widget.isPlaying),
      widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
      size: 36,
      color: Colors.black87,
    );
  }
}

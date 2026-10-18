// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../foundation/app_motion.dart';

/// 页面保留在原位置；快速切换从当前进度继续，仅当前页接收输入和读屏。
class AppTabView extends StatelessWidget {
  final int index;
  final List<Widget> children;

  const AppTabView({super.key, required this.index, required this.children});

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < children.length; i++)
            _TabPanel(active: i == index, child: children[i]),
        ],
      );
}

class _TabPanel extends StatefulWidget {
  final bool active;
  final Widget child;
  const _TabPanel({required this.active, required this.child});

  @override
  State<_TabPanel> createState() => _TabPanelState();
}

class _TabPanelState extends State<_TabPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.active ? 1 : 0,
  )..addStatusListener((_) {
      if (mounted) setState(() {});
    });
  late final CurvedAnimation _effects = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.emphasized,
  );
  late final Animation<Offset> _offset = _effects.drive(
    Tween(begin: const Offset(0, 0.015), end: Offset.zero),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = AppMotion.duration(context, AppMotion.dMedium2);
    _effects.curve = AppMotion.effectsCurve(context);
    _sync();
  }

  @override
  void didUpdateWidget(_TabPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) _sync();
  }

  void _sync() {
    if (_controller.duration == Duration.zero ||
        !TickerMode.valuesOf(context).enabled) {
      _controller.value = widget.active ? 1 : 0;
    } else if (widget.active) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _effects.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Offstage(
        offstage: !widget.active && _controller.isDismissed,
        child: IgnorePointer(
          ignoring: !widget.active,
          child: ExcludeFocus(
            excluding: !widget.active,
            child: ExcludeSemantics(
              excluding: !widget.active,
              child: FadeTransition(
                opacity: _effects,
                child: SlideTransition(
                  position: _offset,
                  child: TickerMode(
                    enabled: widget.active,
                    child: RepaintBoundary(child: widget.child),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

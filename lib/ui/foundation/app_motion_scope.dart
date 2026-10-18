// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

/// 将系统减少动态效果设置传给所有 Material 和自定义动效。
class AppMotionScope extends StatefulWidget {
  final Widget child;
  const AppMotionScope({super.key, required this.child});

  @override
  State<AppMotionScope> createState() => _AppMotionScopeState();
}

class _AppMotionScopeState extends State<AppMotionScope>
    with WidgetsBindingObserver {
  bool get _systemReduceMotion {
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return features.disableAnimations || features.reduceMotion;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
          disableAnimations: media.disableAnimations || _systemReduceMotion),
      child: widget.child,
    );
  }
}

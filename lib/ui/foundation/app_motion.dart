// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'app_motion_theme.dart';
import 'app_spring.dart';

/// Material 动效的时长、缓动及系统辅助功能入口。
abstract final class AppMotion {
  static const dShort1 = Duration(milliseconds: 50);
  static const dShort2 = Duration(milliseconds: 100);
  static const dShort3 = Duration(milliseconds: 150);
  static const dShort4 = Duration(milliseconds: 200);
  static const dMedium1 = Duration(milliseconds: 250);
  static const dMedium2 = Duration(milliseconds: 300);
  static const dMedium3 = Duration(milliseconds: 350);
  static const dMedium4 = Duration(milliseconds: 400);
  static const dLong1 = Duration(milliseconds: 450);
  static const dLong2 = Duration(milliseconds: 500);

  static const Curve standard = Cubic(0.2, 0, 0, 1);
  static const Curve standardDecelerate = Cubic(0, 0, 0, 1);
  static const Curve standardAccelerate = Cubic(0.3, 0, 1, 1);
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);
  static const Curve emphasizedAccelerate = Cubic(0.3, 0, 0.8, 0.15);

  static Duration duration(BuildContext context, Duration value) =>
      MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppMotionTheme.of(context).scale(value);

  static Curve effectsCurve(BuildContext context) =>
      AppMotionTheme.of(context).effectsCurve;
}

/// 只对首屏项目错峰入场，滚动到后续条目时立即显示可交互内容。
class StaggeredEntrance extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration itemDelay;
  final Duration duration;

  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.itemDelay = AppMotion.dShort1,
    this.duration = AppMotion.dMedium2,
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  late final Animation<double> _opacity =
      _controller.drive(CurveTween(curve: AppMotion.emphasizedDecelerate));
  late final Animation<Offset> _offset =
      _opacity.drive(Tween(begin: const Offset(0, 0.06), end: Offset.zero));
  Timer? _delay;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final duration = AppMotion.duration(context, widget.duration);
    if (duration == Duration.zero ||
        !TickerMode.valuesOf(context).enabled ||
        widget.index >= 8) {
      _delay?.cancel();
      _controller.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      _controller.duration = duration;
      _delay = Timer(
        AppMotion.duration(context, widget.itemDelay) *
            widget.index.clamp(0, 7),
        () {
          if (mounted) _controller.forward();
        },
      );
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _offset, child: widget.child),
      );
}

/// 指针反馈不参与点击手势竞争；拖动列表时取消按压，松开后弹簧回位。
class PressScale extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double scaleDown;

  const PressScale(
      {super.key,
      required this.child,
      this.enabled = true,
      this.scaleDown = 0.97});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  int? _pointer;
  Offset? _origin;
  bool _pressed = false;

  void _release() {
    _pointer = null;
    _origin = null;
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  void didUpdateWidget(PressScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _pressed = false;
      _pointer = null;
      _origin = null;
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: widget.enabled
            ? (event) {
                if (_pointer != null) return;
                _pointer = event.pointer;
                _origin = event.position;
                setState(() => _pressed = true);
              }
            : null,
        onPointerMove: (event) {
          if (event.pointer == _pointer &&
              (event.position - _origin!).distance > kTouchSlop) {
            _release();
          }
        },
        onPointerUp: (event) {
          if (event.pointer == _pointer) _release();
        },
        onPointerCancel: (event) {
          if (event.pointer == _pointer) _release();
        },
        child: AppSpring(
          value: _pressed && widget.enabled ? widget.scaleDown : 1,
          builder: (_, value, child) =>
              Transform.scale(scale: value, child: child),
          child: widget.child,
        ),
      );
}

/// 收藏改变时给予短暂的空间反馈，目标和手势语义仍属于内部按钮。
class SelectionFeedback extends StatefulWidget {
  final Widget child;
  final bool trigger;
  const SelectionFeedback(
      {super.key, required this.child, required this.trigger});
  @override
  State<SelectionFeedback> createState() => _SelectionFeedbackState();
}

class _SelectionFeedbackState extends State<SelectionFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController.unbounded(vsync: this);
  bool _animate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate = !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (!_animate) _controller.value = 0;
  }

  @override
  void didUpdateWidget(SelectionFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && _animate) {
      _controller.animateWith(SpringSimulation(
        AppMotionTheme.of(context).spatialSpring,
        _controller.value,
        0,
        4,
        snapToEnd: true,
        tolerance: const Tolerance(distance: 0.0005, velocity: 0.001),
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (_, child) =>
            Transform.scale(scale: 1 + _controller.value, child: child),
      );
}

/// 使用标准 Material 对话框路由，保留焦点循环、主题和安全区行为。
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useRootNavigator = false,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
}) =>
    showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      anchorPoint: anchorPoint,
      animationStyle: AnimationStyle(
        duration: AppMotion.duration(context, AppMotion.dMedium1),
        reverseDuration: AppMotion.duration(context, AppMotion.dShort4),
        curve: AppMotion.effectsCurve(context),
        reverseCurve: AppMotion.emphasizedAccelerate,
      ),
    );

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  Color? barrierColor,
  bool isScrollControlled = false,
  bool useSafeArea = true,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  String? barrierLabel,
  AnimationController? transitionAnimationController,
  Offset? anchorPoint,
  BoxConstraints? constraints,
}) =>
    showModalBottomSheet<T>(
      context: context,
      builder: builder,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      barrierColor: barrierColor,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      showDragHandle: showDragHandle,
      barrierLabel: barrierLabel,
      transitionAnimationController: transitionAnimationController,
      anchorPoint: anchorPoint,
      constraints: constraints,
      sheetAnimationStyle: AnimationStyle(
        duration: AppMotion.duration(context, AppMotion.dMedium2),
        reverseDuration: AppMotion.duration(context, AppMotion.dShort4),
        curve: AppMotion.effectsCurve(context),
        reverseCurve: AppMotion.emphasizedAccelerate,
      ),
    );

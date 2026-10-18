// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../foundation/app_motion.dart';

/// 页面主操作使用较大的触点与标题排版，保留原生按钮的交互和语义。
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const AppPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppButtonTheme.primaryStyleOf(context).copyWith(
      animationDuration: AppMotion.duration(context, AppMotion.dShort4),
    );
    final text = Text(label, textAlign: TextAlign.center);
    if (icon == null) {
      return FilledButton(onPressed: onPressed, style: style, child: text);
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon),
      label: text,
    );
  }
}

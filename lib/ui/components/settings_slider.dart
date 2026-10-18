// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

/// 标签与读数可换行，滑杆始终保有完整的可操作宽度。
class SettingsSlider extends StatelessWidget {
  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final TextStyle? titleStyle;
  final TextStyle? valueStyle;

  const SettingsSlider({
    super.key,
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
    this.titleStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(title, style: titleStyle ?? theme.textTheme.titleSmall),
            Text(valueLabel,
                style: valueStyle ??
                    theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    )),
          ],
        ),
        Semantics(
          label: title,
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            semanticFormatterCallback: (_) => valueLabel,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

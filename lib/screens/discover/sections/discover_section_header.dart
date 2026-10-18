// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../../../ui/components/app_components.dart';

class DiscoverSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onViewAll;

  const DiscoverSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) => AppSectionHeader(
        title: title,
        subtitle: subtitle,
        actionLabel: onViewAll == null ? null : '全部',
        onAction: onViewAll,
      );
}

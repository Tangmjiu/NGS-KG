// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../../theme/app_theme_tokens.dart';
import '../foundation/app_motion.dart';

/// 浏览页面共用的内容宽度；滚动和安全区由页面管理。
class AppPageBody extends StatelessWidget {
  final Widget child;

  const AppPageBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppThemeTokens.of(context).contentMaxWidth,
          ),
          child: child,
        ),
      );
}

class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;
  final EdgeInsetsGeometry? padding;

  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inset = AppThemeTokens.of(context).pagePadding;
    return Padding(
      padding: padding ?? EdgeInsets.fromLTRB(inset, 20, inset, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showBack) ...[
                const BackButton(),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: theme.textTheme.headlineLarge,
                  ),
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: 12),
                ...actions,
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;
  final IconData actionIcon;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding,
    this.actionIcon = Icons.arrow_forward_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppThemeTokens.of(context);
    return Padding(
      padding: padding ??
          EdgeInsets.fromLTRB(
            tokens.pagePadding,
            tokens.sectionSpacing,
            tokens.pagePadding,
            14,
          ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onAction != null) ...[
            const SizedBox(width: 8),
            if (actionLabel != null)
              TextButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon, size: 18),
                label: Text(actionLabel!),
              )
            else
              IconButton.filledTonal(
                tooltip: '查看全部$title',
                onPressed: onAction,
                icon: Icon(actionIcon),
              ),
          ],
        ],
      ),
    );
  }
}

class AppSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;

  const AppSurface({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(
      AppThemeTokens.of(context).cardRadius,
    );
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );
    final surface = Material(
      color: color ?? Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, borderRadius: radius, child: content),
    );
    return onTap == null ? surface : PressScale(child: surface);
  }
}

/// 空状态的纯展示层；主题资源由调用方通过 [illustration] 提供。
class EmptyStateContent extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Widget? illustration;

  const EmptyStateContent({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.illustration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            illustration ??
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Icon(
                      icon,
                      size: 40,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
            const SizedBox(height: 24),
            Text(title,
                textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class AppShortcutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? color;

  const AppShortcutCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppSurface(
      onTap: onTap,
      color: color,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 26),
          const SizedBox(height: 20),
          Text(title, style: theme.textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ],
        ],
      ),
    );
  }
}

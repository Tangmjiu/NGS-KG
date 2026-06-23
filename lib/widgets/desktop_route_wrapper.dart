import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import 'shell_navigation_scope.dart';

/// Wraps a Navigator-pushed route page on desktop with:
/// - A centered content area (not full-width)
/// - A clean header with back button and title
/// - Proper top padding (no mobile safe-area assumptions)
///
/// On mobile/tablet the child is rendered as-is (full-screen, normal Scaffold).
class DesktopRouteWrapper extends StatelessWidget {
  final String? title;
  final Widget child;
  final List<Widget>? actions;
  final double maxWidth;

  const DesktopRouteWrapper({
    super.key,
    this.title,
    required this.child,
    this.actions,
    this.maxWidth = 900,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      mobile: (_) => child,
      tablet: (_) => child,
      desktop: (_) => _buildDesktop(context),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          // ── Back bar ──
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
                  tooltip: '返回',
                  onPressed: () {
                    final scope = ShellNavigationScope.of(context);
                    if (scope != null && scope.canPop) {
                      scope.pop();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
                if (title != null) ...[
                  const SizedBox(width: 4),
                  Text(title!, style: tt.titleMedium),
                ],
                const Spacer(),
                if (actions != null) ...actions!,
                const SizedBox(width: 8),
              ],
            ),
          ),
          // ── Centered content ──
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

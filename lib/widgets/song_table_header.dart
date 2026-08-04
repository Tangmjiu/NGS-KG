import 'package:flutter/material.dart';
import '../utils/responsive.dart';

class SongTableHeader extends StatelessWidget {
  const SongTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktopLayout(context);
    if (!isDesktop) return const SizedBox.shrink();

    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final style = tt.labelMedium?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );

    return Padding(
      padding: const EdgeInsets.only(left: 88, right: 24, top: 16, bottom: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('标题', style: style)),
          Expanded(flex: 2, child: Text('歌手', style: style)),
          Expanded(flex: 2, child: Text('专辑', style: style)),
          SizedBox(width: 80, child: Text('时长', style: style)),
          SizedBox(width: 48, child: Text('', style: style)),
        ],
      ),
    );
  }
}

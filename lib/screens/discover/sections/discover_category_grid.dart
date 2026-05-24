import 'package:flutter/material.dart';
import '../../../constants/discover_constants.dart';
import '../../../models/playlist_tag.dart';

/// 全部分类 — Wrap 网格
class DiscoverCategoryGrid extends StatelessWidget {
  final List<PlaylistTag> tags;
  final List<Map<String, dynamic>> styleTags;

  const DiscoverCategoryGrid({
    super.key,
    required this.tags,
    required this.styleTags,
  });

  @override
  Widget build(BuildContext context) {
    final cats = styleTags.isNotEmpty
        ? styleTags
            .map((e) =>
                (e['tagname'] ?? e['name'] ?? '') as String)
            .toList()
        : tags.map((e) => e.name).toList();

    if (cats.isEmpty) return const SizedBox.shrink();

    final displayCats = cats.length > DiscoverConstants.categoryGridMax
        ? cats.take(DiscoverConstants.categoryGridMax).toList()
        : cats;

    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = (screenWidth / 100)
        .floor()
        .clamp(DiscoverConstants.categoryGridMinColumns,
            DiscoverConstants.categoryGridMaxColumns);
    final itemWidth =
        (screenWidth - 32 - 12 * (crossAxisCount - 1)) / crossAxisCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: displayCats.asMap().entries.map((entry) {
          final i = entry.key;
          final name = entry.value;
          final icon =
              DiscoverConstants.categoryIcons[name] ?? Icons.music_note;
          final color = DiscoverConstants
              .categoryColors[i % DiscoverConstants.categoryColors.length];

          return GestureDetector(
            onTap: () =>
                Navigator.pushNamed(context, '/category/selection'),
            child: Container(
              width: itemWidth,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 26, color: color),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

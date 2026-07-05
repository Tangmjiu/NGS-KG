import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/radio.dart';
import '../../../widgets/horizontal_scroll_list.dart';

/// 电台推荐 — 横向滚动电台卡片
class DiscoverFmRow extends StatelessWidget {
  final List<RadioStation> fmList;

  const DiscoverFmRow({super.key, required this.fmList});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return HorizontalScrollList(
      height: 100,
      cardWidth: 80,
      itemCount: fmList.length,
      itemBuilder: (_, i) {
        final fm = fmList[i];
        final img = (fm.coverUrl ?? '').replaceAll('{size}', '240');
        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/fm',
              arguments: {'fmid': fm.id, 'name': fm.name}),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: img.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: img,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 64,
                          height: 64,
                          color: cs.surfaceContainerHighest,
                          child: const Icon(Icons.radio),
                        ),
                      )
                    : Container(
                        width: 64,
                        height: 64,
                        color: cs.surfaceContainerHighest,
                        child: const Icon(Icons.radio),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                fm.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }
}

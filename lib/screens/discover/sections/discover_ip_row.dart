import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../constants/discover_constants.dart';

/// 编辑精选 — 横向滚动大卡片
class DiscoverIpRow extends StatelessWidget {
  final List<Map<String, dynamic>> ipList;

  const DiscoverIpRow({super.key, required this.ipList});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: ipList.length,
        itemBuilder: (_, i) {
          final ip = ipList[i];
          final imgUrl =
              (ip['img'] as String? ?? ip['sizable_cover'] as String? ?? '')
                  .replaceAll('{size}', DiscoverConstants.ipImageSize);
          final name =
              ip['ip_name'] as String? ?? ip['name'] as String? ?? '';

          return Container(
            width: 260,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  child: imgUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imgUrl,
                          width: 260,
                          height: 112,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 260,
                            height: 112,
                            color: cs.surfaceContainerHighest,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 260,
                            height: 112,
                            color: cs.surfaceContainerHighest,
                            child: Center(
                              child: Text(name,
                                  style: TextStyle(
                                      color: cs.onSurfaceVariant)),
                            ),
                          ),
                        )
                      : Container(
                          width: 260,
                          height: 112,
                          color: cs.surfaceContainerHighest,
                          child: Center(
                            child: Text(name,
                                style:
                                    TextStyle(color: cs.onSurfaceVariant)),
                          ),
                        ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

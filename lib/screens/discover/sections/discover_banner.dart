import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../constants/discover_constants.dart';

/// Banner 轮播
class DiscoverBanner extends StatelessWidget {
  final List<Map<String, dynamic>> banners;

  const DiscoverBanner({super.key, required this.banners});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 160,
      child: PageView.builder(
        padEnds: true,
        pageSnapping: true,
        itemCount: banners.length,
        itemBuilder: (_, i) {
          final banner = banners[i];
          final imgUrl = (banner['banner'] as String? ??
                  banner['img'] as String? ??
                  '')
              .replaceAll('{size}', DiscoverConstants.bannerImageSize);
          final title =
              banner['title'] as String? ?? banner['name'] as String? ?? '';

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: cs.surfaceContainerHighest,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: imgUrl.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: imgUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: cs.surfaceContainerHighest),
                          errorWidget: (_, __, ___) => Container(
                            color: cs.surfaceContainerHighest,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.center,
                              colors: [
                                Colors.black.withValues(alpha: 0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

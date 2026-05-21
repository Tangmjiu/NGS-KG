import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';

class CoverArt extends StatelessWidget {
  final Song song;
  final AnimationController rotationController;

  const CoverArt({
    super.key,
    required this.song,
    required this.rotationController,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (_, constraints) {
        final size = (constraints.maxWidth > constraints.maxHeight
                ? constraints.maxHeight
                : constraints.maxWidth) * 0.7;
        return Center(
          child: Hero(
            tag: 'album_art_${song.hash ?? song.id}',
            child: RotationTransition(
              turns: rotationController,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Semantics(
                  image: true,
                  label: '${song.name} 专辑封面',
                  child: CachedNetworkImage(
                    imageUrl: song.albumCoverUrl ?? '',
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => ExcludeSemantics(
                      child: Container(
                        color: cs.surfaceContainerHighest,
                        child: Icon(Icons.music_note, size: size * 0.25),
                      ),
                    ),
                    errorWidget: (_, __, ___) => ExcludeSemantics(
                      child: Container(
                        color: cs.surfaceContainerHighest,
                        child: Icon(Icons.music_note, size: size * 0.25),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

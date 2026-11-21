// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../utils/watch_motion.dart';
import 'watch_player_primitives.dart' show watchPlayerSpring;

bool watchSameSong(Song? current, Song song) {
  if (current == null) return false;
  if (current.isLocal || song.isLocal) return current.filePath == song.filePath;
  if (current.hash?.isNotEmpty == true && song.hash?.isNotEmpty == true) {
    return current.hash!.toLowerCase() == song.hash!.toLowerCase();
  }
  return identical(current, song) || (song.id != 0 && current.id == song.id);
}

class WatchSongTile extends StatefulWidget {
  const WatchSongTile({
    super.key,
    required this.title,
    this.artist,
    this.subtitle,
    this.isPlaying = false,
    this.onTap,
    this.leading,
    this.trailing,
    this.art,
    this.rank,
  });

  final String title;
  final String? artist;
  final String? subtitle;
  final bool isPlaying;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final ImageProvider? art;
  final int? rank;

  factory WatchSongTile.fromSong({
    required Song song,
    bool isPlaying = false,
    VoidCallback? onTap,
    Widget? leading,
    Widget? trailing,
    int? rank,
  }) {
    return WatchSongTile(
      title: song.name,
      artist: song.artistDisplay,
      subtitle: song.albumName,
      isPlaying: isPlaying,
      onTap: onTap,
      leading: leading,
      trailing: trailing,
      rank: rank,
      art:
          song.albumCoverUrl?.isNotEmpty == true ||
              song.coverData?.isNotEmpty == true
          ? song.coverImageProvider
          : null,
    );
  }

  @override
  State<WatchSongTile> createState() => _WatchSongTileState();
}

class _WatchSongTileState extends State<WatchSongTile>
    with SingleTickerProviderStateMixin {
  late final _press = AnimationController.unbounded(vsync: this, value: 1);

  void _highlight(bool down) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _press.value = 1;
      return;
    }
    _press.animateWith(
      SpringSimulation(
        watchPlayerSpring,
        _press.value,
        down ? 0.96 : 1,
        _press.velocity,
      ),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = widget.isPlaying;
    final pigment = selected
        ? context.select((PlayerProvider? p) => p?.palette?.dominant) ??
              colors.primary
        : colors.surfaceContainerHigh;
    // Derive both text colors from the actual fill, including dark album palettes.
    final ink = selected
        ? (pigment.computeLuminance() > 0.179 ? Colors.black : Colors.white)
        : colors.onSurface;
    final artist = widget.artist?.isNotEmpty == true
        ? widget.artist
        : widget.subtitle;
    final fallback = ColoredBox(
      color: colors.secondaryContainer,
      child: Icon(
        Icons.album_rounded,
        size: 20,
        color: colors.onSecondaryContainer,
      ),
    );
    final art = widget.art;
    return Semantics(
      selected: selected,
      button: widget.onTap != null,
      child: ScaleTransition(
        scale: _press,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: pigment,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onHighlightChanged: _highlight,
              onTap: widget.onTap == null
                  ? null
                  : () {
                      WatchMotion.tap();
                      widget.onTap!();
                    },
              child: Padding(
                padding: EdgeInsets.only(
                  left: 5,
                  right: widget.trailing == null ? 10 : 2,
                ),
                child: Row(
                  children: [
                    widget.leading ??
                        SizedBox.square(
                          dimension: 34,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipOval(
                                  child: art == null
                                      ? fallback
                                      : Image(
                                          image: ResizeImage.resizeIfNeeded(
                                            96,
                                            null,
                                            art,
                                          ),
                                          fit: BoxFit.cover,
                                          excludeFromSemantics: true,
                                          errorBuilder: (_, __, ___) =>
                                              fallback,
                                        ),
                                ),
                              ),
                              if (widget.rank != null)
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    decoration: const ShapeDecoration(
                                      color: Colors.black87,
                                      shape: StadiumBorder(),
                                    ),
                                    child: Text(
                                      '${widget.rank}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (_, constraints) => FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: _SongLabels(
                            title: widget.title,
                            artist: artist,
                            ink: ink,
                            width: constraints.maxWidth,
                          ),
                        ),
                      ),
                    ),
                    if (widget.trailing != null)
                      IconTheme(
                        data: IconThemeData(color: ink),
                        child: widget.trailing!,
                      )
                    else if (selected)
                      Icon(Icons.graphic_eq_rounded, size: 16, color: ink),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SongLabels extends StatelessWidget {
  const _SongLabels({
    required this.title,
    required this.artist,
    required this.ink,
    this.width,
  });
  final String title;
  final String? artist;
  final Color ink;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.1,
              color: ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (artist?.isNotEmpty == true)
            Text(
              artist!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.1,
                color: ink.withValues(alpha: .85),
              ),
            ),
        ],
      ),
    );
  }
}

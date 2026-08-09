import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/theme.dart';

/// Music You 风格封面卡片:
/// 1:1 大圆角封面，长按浮现右下角播放按钮。
/// 移动端适配：移除 MouseRegion hover，改为长按触发播放按钮。
class PlaylistCoverCard extends StatefulWidget {
  final String? coverUrl;
  final String title;
  final double coverSize;
  final double cornerRadius;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;

  const PlaylistCoverCard({
    super.key,
    required this.coverUrl,
    required this.title,
    this.coverSize = 140,
    this.cornerRadius = 16,
    this.onTap,
    this.onPlay,
  });

  @override
  State<PlaylistCoverCard> createState() => _PlaylistCoverCardState();
}

class _PlaylistCoverCardState extends State<PlaylistCoverCard> {
  bool _showPlay = false;

  void _onLongPress() {
    setState(() => _showPlay = !_showPlay);
    if (_showPlay) {
      // 3 秒后自动隐藏播放按钮
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showPlay = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(widget.cornerRadius);

    return GestureDetector(
      onLongPress: () {
        _onLongPress();
        HapticFeedback.selectionClick();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          M3PressScale(
            scaleDown: 0.95,
            child: Container(
              width: widget.coverSize,
              height: widget.coverSize,
              decoration: BoxDecoration(
                borderRadius: radius,
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: radius,
                    child: widget.coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: widget.coverUrl!,
                            width: widget.coverSize,
                            height: widget.coverSize,
                            memCacheWidth: (widget.coverSize * 2).toInt(),
                            memCacheHeight: (widget.coverSize * 2).toInt(),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Icon(
                                Icons.playlist_play,
                                color: cs.onSurfaceVariant),
                          )
                        : Icon(Icons.playlist_play, color: cs.onSurfaceVariant),
                  ),
                  // 右下角播放按钮 (长按弹入)
                  if (widget.onPlay != null)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: AnimatedSlide(
                        offset: Offset(0, _showPlay ? 0 : 0.5),
                        duration: AppMotion.dShort4,
                        curve: Curves.easeOutBack,
                        child: AnimatedOpacity(
                          opacity: _showPlay ? 1 : 0,
                          duration: AppMotion.dShort4,
                          child: Material(
                            color: cs.primary.withValues(alpha: 0.8),
                            shape: const CircleBorder(),
                            elevation: 2,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: widget.onPlay,
                              child: const SizedBox(
                                width: 36,
                                height: 36,
                                child: Icon(Icons.play_arrow_rounded,
                                    color: Colors.white, size: 24),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // 点击区域
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: radius,
                      onTap: widget.onTap,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: widget.coverSize,
            child: Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

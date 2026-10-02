import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A cover art widget that supports both `file://` URIs and network URLs.
///
/// - `file://` URIs → rendered via `Image.file(File(...))`
/// - `http://` / `https://` URLs → rendered via `CachedNetworkImage`
/// - `null` or empty → placeholder container with a music note icon
class LocalCoverArt extends StatelessWidget {
  final String? url;
  final double? size;
  final BoxFit fit;
  final double? borderRadius;
  final Uint8List? coverData;

  const LocalCoverArt({
    super.key,
    this.url,
    this.size,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.coverData,
  });

  @override
  Widget build(BuildContext context) {
    final imageSize = size ?? 48;
    final radius = borderRadius ?? 8;
    final effectiveKey = ValueKey('cover_${url ?? ''}_${imageSize}_$radius');

    return SizedBox(
      width: imageSize,
      height: imageSize,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: _buildContent(context, imageSize),
        key: effectiveKey,
      ),
    );
  }

  Widget _buildContent(BuildContext context, double imageSize) {
    final cacheSize = (imageSize * MediaQuery.devicePixelRatioOf(context)).ceil();
    if (coverData != null && coverData!.isNotEmpty) {
      return Image(
        image: ResizeImage(
          MemoryImage(coverData!),
          width: cacheSize,
          height: cacheSize,
          policy: ResizeImagePolicy.fit,
        ),
        fit: fit,
        width: imageSize,
        height: imageSize,
        errorBuilder: (_, __, ___) => _placeholder(context, imageSize),
      );
    }

    if (url == null || url!.isEmpty) {
      return _placeholder(context, imageSize);
    }

    if (_isRawFilePath(url!)) {
      return _buildFileImage(File(url!), imageSize, context);
    }

    final uri = Uri.tryParse(url!);
    if (uri == null || !uri.isAbsolute) {
      return _placeholder(context, imageSize);
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'file') {
      return _buildFileImage(File(uri.toFilePath()), imageSize, context);
    }
    if (scheme == 'http' || scheme == 'https') {
      return _buildNetworkImage(context, imageSize);
    }
    return _placeholder(context, imageSize);
  }

  bool _isRawFilePath(String path) {
    if (path.length >= 3 && RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(path)) {
      return true;
    }
    if (path.startsWith('/')) return true;
    if (path.startsWith('./') || path.startsWith('.\\')) return true;
    if ((path.contains('\\') || path.contains('/')) &&
        path.contains('.') &&
        !path.startsWith('http')) {
      return true;
    }
    return false;
  }

  Widget _buildFileImage(File file, double imageSize, BuildContext context) {
    final cacheSize = (imageSize * MediaQuery.devicePixelRatioOf(context)).ceil();
    return Image(
      image: ResizeImage(
        FileImage(file),
        width: cacheSize,
        height: cacheSize,
        policy: ResizeImagePolicy.fit,
      ),
      fit: fit,
      width: imageSize,
      height: imageSize,
      errorBuilder: (_, __, ___) => _placeholder(context, imageSize),
    );
  }

  Widget _buildNetworkImage(BuildContext context, double imageSize) {
    final cacheSize = (imageSize * MediaQuery.devicePixelRatioOf(context)).ceil();
    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      width: imageSize,
      height: imageSize,
      // 限制内存中解码尺寸，避免小封面持有全尺寸位图
      memCacheWidth: cacheSize,
      placeholder: (_, __) => _placeholder(context, imageSize),
      errorWidget: (_, __, ___) => _placeholder(context, imageSize),
    );
  }

  Widget _placeholder(BuildContext context, double imageSize) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: imageSize,
      height: imageSize,
      color: cs.surfaceContainerHighest,
      child: Icon(
        Icons.music_note,
        color: cs.onSurfaceVariant,
        size: imageSize * 0.45,
      ),
    );
  }
}

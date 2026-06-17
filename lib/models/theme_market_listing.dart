/// 主题市场条目 — registry.json 中的一条记录
class ThemeMarketListing {
  final String id;
  final String name;
  final String author;
  final int version;
  final String description;
  final String previewUrl;
  final String downloadUrl;
  final List<String> tags;
  final int fileSizeBytes;
  final String? minAppVersion;

  const ThemeMarketListing({
    required this.id,
    required this.name,
    required this.author,
    required this.version,
    required this.description,
    required this.previewUrl,
    required this.downloadUrl,
    required this.tags,
    required this.fileSizeBytes,
    this.minAppVersion,
  });

  factory ThemeMarketListing.fromJson(Map<String, dynamic> json) {
    return ThemeMarketListing(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '未命名',
      author: json['author'] as String? ?? '未知',
      version: json['version'] as int? ?? 1,
      description: json['description'] as String? ?? '',
      previewUrl: json['preview_url'] as String? ?? '',
      downloadUrl: json['download_url'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
      minAppVersion: json['min_app_version'] as String?,
    );
  }

  /// 文件大小的人类可读格式
  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 标签对应的颜色索引（用于 UI 着色）
  int get tagColorIndex => id.hashCode % 7;
}

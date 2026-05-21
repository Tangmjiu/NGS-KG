class SceneCategory {
  final int id;
  final String name;
  final String? iconUrl;

  const SceneCategory({
    required this.id,
    required this.name,
    this.iconUrl,
  });

  factory SceneCategory.fromJson(Map<String, dynamic> json) {
    return SceneCategory(
      id: _toInt(json['scene_id'] ?? json['id'] ?? 0),
      name: (json['scene_name'] ?? json['name'] ?? '') as String,
      iconUrl: _fixUrl(json['scene_pic'] as String? ?? json['img'] as String?),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is num) return v.toInt();
    return 0;
  }

  static String? _fixUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.contains('{size}')) return url.replaceAll(RegExp(r'\{size\}'), '240');
    if (!url.startsWith('http')) return 'https:$url';
    return url;
  }
}

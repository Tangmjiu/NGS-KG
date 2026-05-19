class RankEntry {
  final int id;
  final String name;
  final String? coverUrl;
  final String? bannerUrl;

  const RankEntry({
    required this.id,
    required this.name,
    this.coverUrl,
    this.bannerUrl,
  });

  factory RankEntry.fromJson(Map<String, dynamic> json) {
    String? parseCover(dynamic url) {
      if (url == null) return null;
      final s = url.toString();
      if (s.isEmpty) return null;
      if (s.contains('{size}')) return s.replaceAll(RegExp(r'\{size\}'), '480');
      if (!s.startsWith('http')) return 'https:$s';
      return s;
    }
    return RankEntry(
      id: _toInt(json['rankid'] ?? json['id'] ?? 0),
      name: (json['rankname'] ?? json['name'] ?? '') as String,
      coverUrl: parseCover(json['sizable_cover'] ?? json['imgurl'] ?? json['img_9'] ?? json['cover']),
      bannerUrl: json['banner_9'] as String?,
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is num) return v.toInt();
    return 0;
  }
}

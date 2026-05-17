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
    return RankEntry(
      id: _toInt(json['rankid'] ?? json['id'] ?? 0),
      name: (json['rankname'] ?? json['name'] ?? '') as String,
      coverUrl: json['imgurl'] as String? ?? json['img_9'] as String?,
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

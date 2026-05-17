class PlaylistTag {
  final int id;
  final String name;
  final List<PlaylistTag>? children;

  const PlaylistTag({required this.id, required this.name, this.children});

  factory PlaylistTag.fromJson(Map<String, dynamic> json) {
    final sonList = json['son'] as List<dynamic>?;
    return PlaylistTag(
      id: _toInt(json['tag_id'] ?? json['id'] ?? 0),
      name: (json['tag_name'] ?? json['name'] ?? '') as String,
      children: sonList
          ?.map((e) => PlaylistTag.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is num) return v.toInt();
    return 0;
  }
}

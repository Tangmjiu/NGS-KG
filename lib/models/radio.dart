class RadioStation {
  final int id;
  final String name;
  final String? coverUrl;
  final String? description;

  const RadioStation({
    required this.id,
    required this.name,
    this.coverUrl,
    this.description,
  });

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    return RadioStation(
      id: _toInt(json['fmid'] ?? json['id'] ?? 0),
      name: (json['fmname'] ?? json['name'] ?? '') as String,
      coverUrl: json['imgurl'] as String?,
      description: json['description'] as String?,
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is num) return v.toInt();
    return 0;
  }
}

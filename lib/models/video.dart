class Video {
  final String id;
  final String name;
  final String? artist;
  final String? coverUrl;

  const Video({
    required this.id,
    required this.name,
    this.artist,
    this.coverUrl,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: (json['MvHash'] ?? json['hash'] ?? json['id'] ?? '').toString(),
      name: (json['MvName'] ?? json['name'] ?? json['mvname'] ?? json['title'] ?? '') as String,
      artist: json['SingerName'] as String? ?? json['singername'] as String? ?? json['author'] as String?,
      coverUrl: json['Pic'] as String? ?? json['imgurl'] as String? ?? json['img'] as String?,
    );
  }

  factory Video.fromSearchJson(Map<String, dynamic> json) {
    return Video(
      id: (json['MvHash'] ?? json['hash'] ?? '').toString(),
      name: (json['MvName'] ?? json['name'] ?? json['mvname'] ?? '') as String,
      artist: json['SingerName'] as String? ?? json['singername'] as String?,
      coverUrl: json['Pic'] as String? ?? json['imgurl'] as String? ?? json['img'] as String?,
    );
  }
}

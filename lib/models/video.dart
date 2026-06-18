// MV/Video 功能已暂停适配，代码保留供后续参考
/*
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
    String? parseCover(dynamic url) {
      if (url == null) return null;
      final s = url.toString();
      if (s.isEmpty) return null;
      if (s.contains('{size}')) return s.replaceAll(RegExp(r'\{size\}'), '480');
      if (!s.startsWith('http')) return 'https:$s';
      return s;
    }
    return Video(
      id: (json['MvHash'] ?? json['hash'] ?? json['id'] ?? '').toString(),
      name: (json['MvName'] ?? json['name'] ?? json['mvname'] ?? json['title'] ?? '') as String,
      artist: json['SingerName'] as String? ?? json['singername'] as String? ?? json['author'] as String?,
      coverUrl: parseCover(json['Pic'] ?? json['imgurl'] ?? json['img'] ?? json['sizable_cover'] ?? json['cover']),
    );
  }

  factory Video.fromSearchJson(Map<String, dynamic> json) {
    String? parseCover(dynamic url) {
      if (url == null) return null;
      final s = url.toString();
      if (s.isEmpty) return null;
      if (s.contains('{size}')) return s.replaceAll(RegExp(r'\{size\}'), '480');
      if (!s.startsWith('http')) return 'https:$s';
      return s;
    }
    return Video(
      id: (json['MvHash'] ?? json['hash'] ?? '').toString(),
      name: (json['MvName'] ?? json['name'] ?? json['mvname'] ?? '') as String,
      artist: json['SingerName'] as String? ?? json['singername'] as String?,
      coverUrl: parseCover(json['Pic'] ?? json['imgurl'] ?? json['img'] ?? json['sizable_cover']),
    );
  }
}
*/

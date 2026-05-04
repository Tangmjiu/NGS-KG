class Artist {
  final int id;
  final String name;
  final String? picUrl;
  final int? albumCount;
  final int? musicCount;

  const Artist({
    required this.id,
    required this.name,
    this.picUrl,
    this.albumCount,
    this.musicCount,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? json['artist'] as String? ?? '',
      picUrl: json['picUrl'] as String? ?? json['imgUrl'] as String?,
      albumCount: json['albumCount'] as int?,
      musicCount: json['musicCount'] as int? ?? json['audioCount'] as int?,
    );
  }
}

class Comment {
  final int id;
  final String content;
  final String? userName;
  final String? userAvatar;
  final int likedCount;
  final String? time;

  const Comment({
    required this.id,
    required this.content,
    this.userName,
    this.userAvatar,
    this.likedCount = 0,
    this.time,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return Comment(
      id: json['id'] as int? ?? 0,
      content: json['content'] as String? ?? '',
      userName: user?['nickname'] as String? ?? user?['name'] as String?,
      userAvatar: user?['avatarUrl'] as String?,
      likedCount: json['likedCount'] as int? ?? 0,
      time: json['time'] as String?,
    );
  }
}

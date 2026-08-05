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
    final like = json['like'] as Map<String, dynamic>?;
    // 酷狗评论返回下划线字段（user_name/user_pic/like_count/addtime/
    // comment_id/like.count），需兼容驼峰与嵌套结构。
    String? str(dynamic v) => v?.toString();
    int cnt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    final idRaw = json['comment_id'] ?? json['id'] ?? 0;
    return Comment(
      id: cnt(idRaw),
      content: str(json['content']) ?? '',
      userName: str(json['user_name'] ??
          json['nickname'] ??
          user?['name'] ??
          user?['nickname']),
      userAvatar: str(json['user_pic'] ??
          json['user_img'] ??
          json['avatar'] ??
          user?['avatar'] ??
          user?['pic']),
      likedCount: cnt(like?['count'] ??
          json['like_count'] ??
          json['likedCount'] ??
          json['like_num'] ??
          json['count']),
      time: str(json['addtime'] ?? json['add_time'] ?? json['time']),
    );
  }
}

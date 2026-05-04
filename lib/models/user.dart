class User {
  final int? userId;
  final String? nickname;
  final String? avatarUrl;
  final String? token;

  const User({this.userId, this.nickname, this.avatarUrl, this.token});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['userId'] as int? ?? json['userid'] as int?,
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatarUrl'] as String? ?? json['pic'] as String?,
      token: json['token'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (userId != null) 'userId': userId,
        if (nickname != null) 'nickname': nickname,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (token != null) 'token': token,
      };
}

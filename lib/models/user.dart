class User {
  final int? userId;
  final String? nickname;
  final String? avatarUrl;
  final String? token;
  final int? vipType;
  final int? isVip;

  const User({
    this.userId,
    this.nickname,
    this.avatarUrl,
    this.token,
    this.vipType,
    this.isVip,
  });

  bool get isVipActive => isVip == 1;

  String get vipLevelDisplay {
    if (!isVipActive) return '普通用户';
    switch (vipType) {
      case 1:
        return '付费音乐包';
      case 6:
        return '豪华VIP';
      default:
        return 'VIP $vipType';
    }
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['userId'] as int? ?? json['userid'] as int?,
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatarUrl'] as String? ?? json['pic'] as String?,
      token: json['token'] as String?,
      vipType: json['vip_type'] as int?,
      isVip: json['is_vip'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (userId != null) 'userId': userId,
        if (nickname != null) 'nickname': nickname,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (token != null) 'token': token,
      };
}

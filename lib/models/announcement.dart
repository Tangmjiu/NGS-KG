/// 公告数据模型
class Announcement {
  final String id; // 公告唯一 ID，用于已读去重
  final String title; // 公告标题
  final String content; // 公告正文（Markdown 格式）
  final DateTime publishTime; // 发布时间
  final String? versionConstraint; // 针对的版本限制（例如 "<=1.5.0"，可选）
  final String? actionUrl; // 跳转链接（例如点击去加群或查看网页，可选）
  final bool force; // 是否强制弹出（即使已读，每次启动仍弹窗，适用于紧急通知）
  final bool dismissible; // 是否可关闭（如果为 false，必须同意或无法跳过）

  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.publishTime,
    this.versionConstraint,
    this.actionUrl,
    this.force = false,
    this.dismissible = true,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      publishTime: DateTime.tryParse(json['publishTime']?.toString() ?? '') ??
          DateTime.now(),
      versionConstraint: json['versionConstraint']?.toString(),
      actionUrl: json['actionUrl']?.toString(),
      force: json['force'] as bool? ?? false,
      dismissible: json['dismissible'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'publishTime': publishTime.toIso8601String(),
      'versionConstraint': versionConstraint,
      'actionUrl': actionUrl,
      'force': force,
      'dismissible': dismissible,
    };
  }
}

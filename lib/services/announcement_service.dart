import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/announcement.dart';
import 'update_checker.dart';

/// 公告处理服务
class AnnouncementService {
  static const _repo = 'Tangmjiu/NGS-KG';
  // 应用读取去掉 .example 后缀的正式公告文件
  static const _apiUrl =
      'https://fastly.jsdelivr.net/gh/$_repo@android/assets/config/announcement.json';
  static const _readListKey = 'read_announcement_ids';

  /// 获取最新且适合当前客户端的一条符合条件的未读公告
  static Future<Announcement?> fetchLatest() async {
    try {
      // 请求 GitHub/CDN 静态文件列表（不经过 ApiClient 以防被记 404 日志）
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'User-Agent': 'NGS-KG+'},
      ));

      final res = await dio.get<dynamic>(_apiUrl);
      if (res.data == null) return null;

      List<dynamic> list;
      if (res.data is List) {
        list = res.data as List;
      } else {
        return null;
      }

      // 解析公告列表
      final announcements = list
          .map((json) {
            if (json is Map<String, dynamic>) {
              return Announcement.fromJson(json);
            }
            return null;
          })
          .whereType<Announcement>()
          .toList();

      if (announcements.isEmpty) return null;

      // 按发布时间降序排序（最新发布的排最前面）
      announcements.sort((a, b) => b.publishTime.compareTo(a.publishTime));

      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      final prefs = await SharedPreferences.getInstance();
      final readIds = prefs.getStringList(_readListKey) ?? [];

      // 遍历并找出第一条符合当前版本且未读的公告
      for (final a in announcements) {
        if (a.id.isEmpty) continue;

        // 版本约束比对
        if (a.versionConstraint != null) {
          final isMatch =
              checkVersionConstraint(currentVersion, a.versionConstraint!);
          if (!isMatch) continue; // 版本不合，跳过
        }

        // 已读比对
        if (!a.force && readIds.contains(a.id)) {
          continue; // 已读且非强制，跳过
        }

        // 匹配成功，返回最新的一条
        return a;
      }

      return null;
    } catch (_) {
      return null; // 出错则静默忽略
    }
  }

  /// 标记公告为已读
  static Future<void> markAsRead(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readIds = prefs.getStringList(_readListKey) ?? [];
      if (!readIds.contains(id)) {
        readIds.add(id);
        await prefs.setStringList(_readListKey, readIds);
      }
    } catch (_) {}
  }

  /// 检查当前版本是否符合约束
  static bool checkVersionConstraint(String currentVersion, String constraint) {
    final cleanConstraint = constraint.trim();
    if (cleanConstraint == '*' ||
        cleanConstraint.toLowerCase() == 'all' ||
        cleanConstraint.isEmpty) {
      return true; // 匹配所有版本
    }

    // 解析操作符和目标版本号，如 "<=1.5.0" -> "<=" 和 "1.5.0"
    final regExp = RegExp(r'^([<>]=?|=)?\s*([0-9a-zA-Z.-]+)$');
    final match = regExp.firstMatch(cleanConstraint);
    if (match == null) return false;

    final operator = match.group(1) ?? '='; // 默认是等于
    final targetVersion = match.group(2)!;

    // 清洗本地版本号：去掉 + 号之后的 build number (例如 1.5.1-preview+1 -> 1.5.1-preview)
    final cleanCurrent = currentVersion.split('+').first;

    final comparison =
        UpdateChecker.compareVersions(cleanCurrent, targetVersion);

    switch (operator) {
      case '=':
        return comparison == 0;
      case '<':
        return comparison < 0;
      case '<=':
        return comparison <= 0;
      case '>':
        return comparison > 0;
      case '>=':
        return comparison >= 0;
      default:
        return false;
    }
  }
}

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'api_client.dart';

/// GitHub Release 信息
class ReleaseInfo {
  final String tagName;    // e.g. "v1.1.0"
  final String version;    // e.g. "1.1.0"
  final String body;       // CHANGELOG / release notes
  final String? downloadUrl; // APK download URL (first asset)

  const ReleaseInfo({
    required this.tagName,
    required this.version,
    required this.body,
    this.downloadUrl,
  });

  bool isNewerThan(String currentVersion) {
    return UpdateChecker.compareVersions(version, currentVersion) > 0;
  }
}

/// GitHub Release 更新检查
class UpdateChecker {
  static const _repo = 'Tangmjiu/NGS-KG';
  static const _apiUrl = 'https://api.github.com/repos/$_repo/releases/latest';

  /// 检查更新：获取本地版本 → 拉取 GitHub 最新 Release → 对比
  static Future<ReleaseInfo?> check() async {
    try {
      // 获取本地版本
      final info = await PackageInfo.fromPlatform();
      final currentVersion = _cleanVersion(info.version);

      // 拉取 GitHub 最新 Release
      final client = ApiClient.instance;
      final res = await client.get(
        _apiUrl,
        options: Options(extra: {'silent': true}),
      );

      final data = res.data as Map<String, dynamic>?;
      if (data == null) return null;

      final tagName = data['tag_name'] as String? ?? '';
      final body = data['body'] as String? ?? '';
      final version = tagName.replaceFirst(RegExp(r'^v', caseSensitive: false), '');

      // 获取下载链接（找 Android APK asset）
      String? downloadUrl;
      final assets = data['assets'] as List<dynamic>?;
      if (assets != null) {
        for (final asset in assets) {
          if (asset is Map) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            final url = asset['browser_download_url'] as String?;
            if (url != null && (name.contains('apk') || name.contains('release'))) {
              downloadUrl = url;
              break;
            }
          }
        }
      }

      final release = ReleaseInfo(
        tagName: tagName,
        version: version,
        body: body,
        downloadUrl: downloadUrl,
      );

      // 只有新版才返回
      if (release.isNewerThan(currentVersion)) return release;
      return null;
    } catch (_) {
      return null; // 网络失败或解析失败，静默处理
    }
  }

  /// 清理版本号：去掉 v 前缀、仅保留 x.y.z
  static String _cleanVersion(String v) {
    return v.replaceFirst(RegExp(r'^v', caseSensitive: false), '').split('+').first;
  }

  /// 语义化版本对比：返回 1 (a>b), 0 (a==b), -1 (a<b)
  static int compareVersions(String a, String b) {
    final partsA = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final partsB = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    // 补齐到 3 段
    while (partsA.length < 3) partsA.add(0);
    while (partsB.length < 3) partsB.add(0);

    for (int i = 0; i < 3; i++) {
      final diff = partsA[i].compareTo(partsB[i]);
      if (diff != 0) return diff;
    }
    return 0;
  }
}

import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'device_service.dart';

/// GitHub Release 信息
class ReleaseInfo {
  final String tagName; // e.g. "v1.1.0"
  final String version; // e.g. "1.1.0"
  final String body; // CHANGELOG / release notes
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

      // 拉取 GitHub 最新 Release（用 Dio 直连，避免 ApiClient 记录 404 日志）
      final data = await _fetchLatestRelease();
      if (data == null) return null;

      final tagName = data['tag_name'] as String? ?? '';
      final body = data['body'] as String? ?? '';
      final version =
          tagName.replaceFirst(RegExp(r'^v', caseSensitive: false), '');

      // 平台和 ABI 检测，匹配对应下载链接
      String? downloadUrl;

      if (Platform.isAndroid) {
        final abi = await DeviceService.instance.getAbi() ?? 'arm64-v8a';
        // 优先匹配当前 ABI 的 release 包
        downloadUrl = _matchAsset(data['assets'], _androidMatcher(abi));
        // 如果没有，匹配不带任何 ABI 标识的通用 release 包（比如单个 fat apk）
        downloadUrl ??= _matchAsset(data['assets'], (name) {
          if (!name.endsWith('.apk')) return false;
          if (!name.contains('release')) return false;
          // 不包含任何已知 ABI 关键字，说明是 fat/universal APK
          return !name.contains('arm64') &&
              !name.contains('v8a') &&
              !name.contains('v7a') &&
              !name.contains('x86');
        });
      } else if (Platform.isWindows) {
        downloadUrl = _matchAsset(data['assets'], _windowsMatcher);
      } else if (Platform.isLinux) {
        // 优先 deb 包，其次 flatpak
        downloadUrl = _matchAsset(
                data['assets'], (name) => name.endsWith('.deb')) ??
            _matchAsset(data['assets'], (name) => name.endsWith('.flatpak'));
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

  /// 遍历 assets，找到第一个匹配 [predicate] 的下载 URL。
  static String? _matchAsset(
      dynamic assets, bool Function(String name) predicate) {
    if (assets is! List) return null;
    for (final asset in assets) {
      if (asset is Map) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        final url = asset['browser_download_url'] as String?;
        if (url != null && predicate(name)) return url;
      }
    }
    return null;
  }

  /// Android 匹配器：找 release APK + 匹配当前 ABI。
  static bool Function(String) _androidMatcher(String abi) {
    return (String name) {
      if (!name.endsWith('.apk')) return false;
      if (!name.contains('release')) return false;
      return name.contains(abi);
    };
  }

  /// Windows 匹配器：找 exe、msix 安装包，或者 zip 压缩包
  static bool _windowsMatcher(String name) {
    if (name.endsWith('.exe') || name.endsWith('.msix')) {
      return name.contains('release') || name.contains('setup');
    }
    if (name.endsWith('.zip')) {
      return name.contains('windows') && name.contains('release');
    }
    return false;
  }

  /// 清理版本号：去掉 v 前缀、仅保留 x.y.z
  static String _cleanVersion(String v) {
    return v
        .replaceFirst(RegExp(r'^v', caseSensitive: false), '')
        .split('+')
        .first;
  }

  /// 直接用 Dio 请求 GitHub API（不走 ApiClient，避免 404 被日志记录）
  static Future<Map<String, dynamic>?> _fetchLatestRelease() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'User-Agent': 'NGS-KG+'},
      ));
      final res = await dio.get<Map<String, dynamic>>(_apiUrl);
      return res.data;
    } catch (_) {
      return null; // 404 或其他网络错误，静默处理
    }
  }

  /// 语义化版本对比：返回 1 (a>b), 0 (a==b), -1 (a<b)
  static int compareVersions(String a, String b) {
    // 提取数字部分，如 "1.5.2-preview" -> "1.5.2"
    final numPattern = RegExp(r'^(\d+(?:\.\d+)*)');
    final matchA = numPattern.firstMatch(a);
    final matchB = numPattern.firstMatch(b);

    final numStrA = matchA != null ? matchA.group(1)! : a;
    final numStrB = matchB != null ? matchB.group(1)! : b;

    final partsA = numStrA.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final partsB = numStrB.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    // 补齐到相同长度，且至少为 3 段
    final length =
        partsA.length > partsB.length ? partsA.length : partsB.length;
    final targetLength = length < 3 ? 3 : length;

    while (partsA.length < targetLength) partsA.add(0);
    while (partsB.length < targetLength) partsB.add(0);

    for (int i = 0; i < targetLength; i++) {
      final diff = partsA[i].compareTo(partsB[i]);
      if (diff != 0) return diff;
    }

    // 数字部分完全一样，对比是否有 prerelease 后缀
    // 根据 SemVer: 无后缀（正式版） > 有后缀（预览版）
    final hasSuffixA = a.contains('-');
    final hasSuffixB = b.contains('-');

    if (!hasSuffixA && hasSuffixB) return 1; // a 是正式版，b 是预览版 -> a 更先进
    if (hasSuffixA && !hasSuffixB) return -1; // b 是正式版，a 是预览版 -> b 更先进

    return 0;
  }
}

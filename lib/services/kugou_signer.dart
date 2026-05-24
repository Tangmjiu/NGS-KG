import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// 酷狗请求签名器
///
/// 移植自 MakcRe/KuGouMusicApi 的 util/helper.js 与 util/crypto.js。
/// 所有签名算法均在此实现，无需依赖外部 Node.js 代理。
///
/// 支持两种模式：
/// - Lite（概念版）: appid=3116, clientver=11440
/// - Standard（标准版）: appid=1005, clientver=20489
class KugouSigner {
  // ─── 常量 ───

  /// 标准版 Android 签名密钥
  static const String _androidSecret = 'OIlwieks28dk2k092lksi2UIkp';

  /// Lite 版 Android 签名密钥
  static const String _androidLiteSecret = 'LnT6xpN3khm36zse0QzvmgTZ3waWdRSA';

  /// 标准版 signKey 密钥
  static const String _signKeySecret = '57ae12eb6890223e355ccfcb74edf70d';

  /// Lite 版 signKey 密钥
  static const String _signKeyLiteSecret = '185672dd44712f60bb1736df5a377e82';

  /// Web 版签名密钥
  static const String _webSecret = 'NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt';

  /// 标准版 appid (from config.json)
  static const int appidStandard = 1005;

  /// 标准版 clientver
  static const int clientVerStandard = 20489;

  /// Lite 版 appid
  static const int appidLite = 3116;

  /// Lite 版 clientver
  static const int clientVerLite = 11440;

  // ─── 配置 ───

  /// 是否使用 Lite（概念版）模式
  final bool isLite;

  KugouSigner({this.isLite = true});

  // ─── 客户端生成函数（移植自 util.js） ───

  /// 生成 GUID（UUID 格式，移植自 getGuid）
  static String generateGuid() {
    final r = Random.secure();
    int hex4() => (65536 * (1 + r.nextDouble())).toInt() & 0xFFFF;
    String hex() => hex4().toRadixString(16).padLeft(4, '0').substring(0, 4);
    return '${hex()}${hex()}-${hex()}-${hex()}-${hex()}-${hex()}${hex()}${hex()}';
  }

  /// 生成 16 位随机大写字符串（移植自 randomString）
  static String randomString([int len = 16]) {
    const chars = '1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final r = Random.secure();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// 基于 GUID 计算 MID（移植自 calculateMid）
  static String calculateMid(String guid) {
    final digest = md5.convert(utf8.encode(guid)).toString();
    // 将 128 位 hex 转换为十进制大整数
    int result = 0;
    for (int i = 0; i < digest.length; i++) {
      result = result * 16 + int.parse(digest[i], radix: 16);
    }
    return result.toString();
  }

  // ─── 签名算法（移植自 helper.js） ───

  /// Android 版参数签名
  ///
  /// 算法: md5(secret + sortedParams + data + secret)
  String signatureAndroidParams(Map<String, dynamic> params,
      [String data = '']) {
    final secret = isLite ? _androidLiteSecret : _androidSecret;
    final keys = params.keys.toList()..sort();
    final paramsStr = keys.map((k) {
      final v = params[k];
      final val = v is Map || v is List ? jsonEncode(v) : v.toString();
      return '$k=$val';
    }).join('');
    return md5
        .convert(utf8.encode('$secret$paramsStr$data$secret'))
        .toString();
  }

  /// Register 设备注册版参数签名
  ///
  /// 算法: md5("1014" + sortedValues + "1014")
  String signatureRegisterParams(Map<String, dynamic> params) {
    final values = params.values
        .map((v) => v.toString())
        .toList()
      ..sort();
    final paramsStr = values.join('');
    return md5.convert(utf8.encode('1014${paramsStr}1014')).toString();
  }

  /// Web 版参数签名
  String signatureWebParams(Map<String, dynamic> params) {
    final keys = params.keys.toList()..sort();
    final paramsStr = keys.map((k) => '$k=${params[k]}').join('');
    return md5
        .convert(utf8.encode('$_webSecret$paramsStr$_webSecret'))
        .toString();
  }

  /// signKey 加密 — 用于获取播放 URL 时的 key 参数
  ///
  /// 算法: md5(hash + secret + appid + mid + userid)
  String signKey(String hash, String mid,
      {int? userId, int? appidOverride}) {
    final secret = isLite ? _signKeyLiteSecret : _signKeySecret;
    final appid = appidOverride ?? (isLite ? appidLite : appidStandard);
    return md5
        .convert(utf8.encode(
            '$hash$secret$appid$mid${userId ?? 0}'))
        .toString();
  }

  /// signParams — 用于一些新版接口的参数签名
  String signParams(Map<String, dynamic> params,
      [String data = '']) {
    const str = 'R6snCXJgbCaj9WFRJKefTMIFp0ey6Gza';
    final keys = params.keys.toList()..sort();
    final paramsStr = keys.map((k) => '$k${params[k]}').join('');
    return md5
        .convert(utf8.encode('$paramsStr$data$str'))
        .toString();
  }

  // ─── 请求构造辅助 ───

  int get appid => isLite ? appidLite : appidStandard;
  int get clientver => isLite ? clientVerLite : clientVerStandard;

  /// 构建默认请求参数（移植自 request.js 的 defaultParams）
  Map<String, dynamic> buildDefaultParams(
    String dfid,
    String mid, {
    String? token,
    int? userId,
    String uuid = '-',
  }) {
    final now = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
    final params = <String, dynamic>{
      'dfid': dfid,
      'mid': mid,
      'uuid': uuid,
      'appid': appid,
      'clientver': clientver,
      'clienttime': now,
    };
    if (token != null && token.isNotEmpty) params['token'] = token;
    if (userId != null && userId != 0) params['userid'] = userId;
    return params;
  }

  /// 构建请求头（移植自 request.js 的 headers）
  Map<String, String> buildHeaders(
    String dfid,
    String mid, {
    int? clienttime,
    String? realIp,
  }) {
    final t = clienttime ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final headers = <String, String>{
      'dfid': dfid,
      'clienttime': '$t',
      'mid': mid,
      'kg-rc': '1',
      'kg-thash': '5d816a0',
      'kg-rec': '1',
      'kg-rf': 'B9EDA08A64250DEFFBCADDEE00F8F25F',
    };
    if (realIp != null && realIp.isNotEmpty) {
      headers['X-Real-IP'] = realIp;
      headers['X-Forwarded-For'] = realIp;
    }
    return headers;
  }
}

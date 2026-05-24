/// 酷狗设备指纹信息
///
/// 对应 MoeKoeMusic / KuGouMusicApi 中 /register/dev 返回及补充计算的字段。
/// 设备指纹将用于 Authorization 头中传递给 API 代理服务器。
class DeviceInfo {
  /// 设备指纹标识（由 API 下发，核心字段）
  final String dfid;

  /// 基于 GUID MD5 计算的设备 MID
  final String mid;

  /// 全局唯一设备标识符（客户端生成）
  final String guid;

  /// 开发设备标识（大写随机字符串）
  final String serverDev;

  /// MAC 地址（默认 02:00:00:00:00:00）
  final String mac;

  const DeviceInfo({
    required this.dfid,
    required this.mid,
    required this.guid,
    required this.serverDev,
    required this.mac,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      dfid: (json['dfid'] as String?) ?? '',
      mid: (json['mid'] as String?) ?? '',
      guid: (json['guid'] as String?) ?? '',
      serverDev: (json['serverDev'] as String?) ?? '',
      mac: (json['mac'] as String?) ?? '02:00:00:00:00:00',
    );
  }

  Map<String, dynamic> toJson() => {
        'dfid': dfid,
        'mid': mid,
        'guid': guid,
        'serverDev': serverDev,
        'mac': mac,
      };

  /// 构建 MoeKoeMusic 风格的 Authorization 部件列表
  List<String> toAuthParts({String? token, String? userId}) {
    final parts = <String>[];
    if (token != null && token.isNotEmpty) parts.add('token=$token');
    if (userId != null && userId.isNotEmpty) parts.add('userid=$userId');
    parts.add('dfid=$dfid');
    if (mid.isNotEmpty) parts.add('KUGOU_API_MID=$mid');
    if (guid.isNotEmpty) parts.add('KUGOU_API_GUID=$guid');
    if (serverDev.isNotEmpty) parts.add('KUGOU_API_DEV=$serverDev');
    if (mac.isNotEmpty) parts.add('KUGOU_API_MAC=$mac');
    return parts;
  }

  /// 构建完整的 Authorization 头字符串
  String buildAuthHeader({String? token, String? userId}) {
    return toAuthParts(token: token, userId: userId).join(';');
  }

  bool get isValid => dfid.isNotEmpty;

  @override
  String toString() =>
      'DeviceInfo(dfid=$dfid, mid=$mid, guid=$guid, serverDev=$serverDev, mac=$mac)';
}

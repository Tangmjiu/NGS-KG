/// /user/vip/detail 响应解析
///
/// 真实 API 返回示例:
/// ```json
/// {
///   "is_vip": 1,
///   "product_type": "tvip",  // 或 "svip"
///   "vip_begin_time": "2026-02-04 13:31:08",
///   "vip_end_time": "2026-02-05 13:31:08",
///   "vip_clearday": "2026-02-04 13:31:08",
///   "is_paid_vip": 0,
///   "paid_vip_expire_time": "",
///   "vip_limit_quota": {},
///   "busi_type": "concept"
/// }
/// ```
class VipInfo {
  /// 是否 VIP（1=有效）
  final int isVip;

  /// VIP 类型数值（1=付费音乐包, 6=豪华VIP，可能为 null）
  final int? vipType;

  /// 产品类型（"tvip"=普通VIP, "svip"=超级VIP/豪华VIP）
  final String? productType;

  /// 开通时间
  final DateTime? vipBeginTime;

  /// 到期时间
  final DateTime? vipEndTime;

  /// 清空日（一般等于开通时间）
  final DateTime? vipClearday;

  /// 是否付费 VIP
  final int? isPaidVip;

  /// 付费 VIP 到期时间（字符串，可能为空）
  final String? paidVipExpireTime;

  /// VIP 限制配额（下载等）
  final Map<String, dynamic>? vipLimitQuota;

  /// 业务类型
  final String? busiType;

  const VipInfo({
    required this.isVip,
    this.vipType,
    this.productType,
    this.vipBeginTime,
    this.vipEndTime,
    this.vipClearday,
    this.isPaidVip,
    this.paidVipExpireTime,
    this.vipLimitQuota,
    this.busiType,
  });

  bool get isVipActive => isVip == 1;

  /// VIP 显示名称
  String get displayName {
    if (!isVipActive) return '普通用户';

    // 优先用 product_type（概念版 API）
    if (productType != null) {
      switch (productType) {
        case 'svip':
          return '超级VIP';
        case 'tvip':
          return 'VIP';
      }
    }

    // 回退到 vip_type 数值（标准版 API）
    switch (vipType) {
      case 1:
        return '付费音乐包';
      case 6:
        return '豪华VIP';
      default:
        return 'VIP';
    }
  }

  /// 到期天数提示（如 "剩余 3 天"、"已过期"、"永久有效"）
  String get expirationText {
    if (!isVipActive) return '';
    final end = vipEndTime;
    if (end == null) return '';

    final now = DateTime.now();
    if (end.isBefore(now)) return '已过期';

    final days = end.difference(now).inDays;
    if (days <= 0) return '今天到期';
    if (days == 1) return '明天到期';
    if (days < 30) return '剩余 $days 天';
    return '到期 ${_formatDate(end)}';
  }

  /// VIP 信息摘要（用于详细页面）
  String get summary {
    if (!isVipActive) return '普通用户';
    final sb = StringBuffer(displayName);
    final expire = expirationText;
    if (expire.isNotEmpty) {
      sb.write(' · $expire');
    }
    return sb.toString();
  }

  /// 格式化 VIP 标签颜色（浅色/深色模式自适应）
  (bool isPremium, bool isSvip) get badgeType {
    if (!isVipActive) return (false, false);
    if (productType == 'svip' || vipType == 6) return (true, true);
    return (true, false);
  }

  factory VipInfo.fromJson(Map<String, dynamic> json) {
    DateTime? parseTime(String? key) {
      final v = json[key] as String?;
      if (v == null || v.isEmpty) return null;
      return DateTime.tryParse(v);
    }

    return VipInfo(
      isVip: json['is_vip'] as int? ?? 0,
      vipType: json['vip_type'] as int?,
      productType: json['product_type'] as String?,
      vipBeginTime: parseTime('vip_begin_time'),
      vipEndTime: parseTime('vip_end_time'),
      vipClearday: parseTime('vip_clearday'),
      isPaidVip: json['is_paid_vip'] as int?,
      paidVipExpireTime: json['paid_vip_expire_time'] as String?,
      vipLimitQuota: json['vip_limit_quota'] as Map<String, dynamic>?,
      busiType: json['busi_type'] as String?,
    );
  }
}

String _formatDate(DateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

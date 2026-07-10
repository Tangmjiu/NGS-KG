/// 音质级别常量、回退链、标签映射
///
/// 编码质量（Encoding）和音效（Effect）完全分开两个体系：
///   编码质量：128 → 320 → flac → high
///   音效：    viper_atmos / viper_clear / viper_tape
///
/// 调用 /song/url 时 quality 参数即用这些 key。
class Quality {
  Quality._();

  /// 编码音质级别（从低到高）—— 只有纯编码品质等级
  static const List<String> levels = [
    '128',
    '320',
    'flac',
    'high',
  ];

  /// 编码音质显示标签映射
  static const Map<String, String> labels = {
    '128': '标准',
    '320': 'HQ',
    'flac': 'SQ',
    'high': 'Hi-Res',
  };

  /// 验证并规范化编码音质 key，无效则回退到 '128'
  static String normalize(String? quality) {
    if (quality != null && levels.contains(quality)) return quality;
    return '128';
  }

  /// 构建编码音质降级回退链：从 [quality] 向下逐级尝试到 '128'
  ///
  /// 例：fallbackChain('flac') → ['flac', '320', '128']
  static List<String> fallbackChain(String quality) {
    final idx = levels.indexOf(normalize(quality));
    return levels.sublist(0, idx + 1).reversed.toList();
  }

  /// 获取编码音质显示标签
  static String label(String quality) => labels[quality] ?? quality;

  // ─── 音效体系（独立于编码质量） ───

  /// 可用音效列表（按优先级从高到低）
  static const List<String> effects = [
    'viper_tape',
    'viper_clear',
    'viper_atmos',
  ];

  /// 音效显示标签映射（含 'none' 关闭）
  static const Map<String, String> effectLabels = {
    'none': '关闭',
    'viper_atmos': '全景声',
    'viper_clear': '蝰蛇超清',
    'viper_tape': '母带',
  };

  /// 验证音效 key，无效回退到 'none'
  static String normalizeEffect(String? effect) {
    if (effect != null && (effect == 'none' || effects.contains(effect))) {
      return effect;
    }
    return 'none';
  }

  /// 获取音效显示标签
  static String effectLabel(String effect) =>
      effectLabels[effect] ?? effect;

  /// 所有 /privilege/lite 中可能出现的 quality key（编码 + 音效）
  static const List<String> allKnown = [
    '128', '320', 'flac', 'high',
    'viper_atmos', 'viper_clear', 'viper_tape',
  ];
}

/// 单首歌曲可用的某个音质选项（来自 /privilege/lite）
class QualityOption {
  final String value; // 音质 key，如 'flac', '320'
  final String hash; // 该音质对应的文件 hash
  final String label; // 显示标签
  final int level; // 特权级别（来自 API）

  const QualityOption({
    required this.value,
    required this.hash,
    required this.label,
    this.level = 0,
  });

  factory QualityOption.fromPrivilegeJson(Map<String, dynamic> json) {
    final value = json['quality'] as String? ?? '128';
    return QualityOption(
      value: value,
      hash: json['hash'] as String? ?? '',
      label: Quality.labels[value] ?? value,
      level: json['level'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'value': value,
        'hash': hash,
        'label': label,
        'level': level,
      };
}

/// /privilege/lite 响应的解析结果
///
/// 拆分为两个独立列表：
///   [options]       — 编码音质（128/320/flac/high）
///   [effectOptions] — 音效     （viper_atmos / viper_clear / viper_tape）
class PrivilegeInfo {
  final List<QualityOption> options; // 编码音质（按级别从高到低排序）
  final List<QualityOption> effectOptions; // 音效（按优先级从高到低排序）

  const PrivilegeInfo({
    required this.options,
    this.effectOptions = const [],
  });

  factory PrivilegeInfo.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] as List<dynamic>? ?? [];
    final seenQualities = <String>{};
    final seenEffects = <String>{};
    final options = <QualityOption>[];
    final effectOptions = <QualityOption>[];

    // 遍历 data 列表 + 每项的 relate_goods
    for (final item in raw) {
      if (item is! Map) continue;
      _addIfValid(item, seenQualities, seenEffects, options, effectOptions);
      final relateGoods = item['relate_goods'] as List<dynamic>? ?? [];
      for (final rg in relateGoods) {
        if (rg is Map) _addIfValid(rg, seenQualities, seenEffects, options, effectOptions);
      }
    }

    // 编码音质按 Quality.levels 从高到低排序
    options.sort((a, b) => Quality.levels
        .indexOf(b.value)
        .compareTo(Quality.levels.indexOf(a.value)));

    // 音效按 Quality.effects 从高到低排序
    effectOptions.sort((a, b) => Quality.effects
        .indexOf(b.value)
        .compareTo(Quality.effects.indexOf(a.value)));

    return PrivilegeInfo(options: options, effectOptions: effectOptions);
  }

  static void _addIfValid(
    Map item,
    Set<String> seenQualities,
    Set<String> seenEffects,
    List<QualityOption> options,
    List<QualityOption> effectOptions,
  ) {
    final hash = item['hash'] as String?;
    final quality = item['quality'] as String?;
    final level = item['level'] as int? ?? 0;
    if (hash == null || hash.isEmpty) return;
    if (quality == null || !Quality.allKnown.contains(quality)) return;
    if (level == 0) return;

    if (Quality.levels.contains(quality)) {
      if (seenQualities.contains(quality)) return;
      seenQualities.add(quality);
      options.add(QualityOption(
        value: quality,
        hash: hash,
        label: Quality.labels[quality] ?? quality,
        level: level,
      ));
    } else if (Quality.effects.contains(quality)) {
      if (seenEffects.contains(quality)) return;
      seenEffects.add(quality);
      effectOptions.add(QualityOption(
        value: quality,
        hash: hash,
        label: Quality.effectLabels[quality] ?? quality,
        level: level,
      ));
    }
  }

  /// 根据用户首选音质 [preferred] 构建候选链
  ///
  /// 只保留 privilege 中明确可用的级别，按降级链顺序返回。
  /// 如果 privilege 无数据，用 [fallbackHash] 回退。
  List<QualityOption> candidates(String preferred, {String? fallbackHash}) {
    final prefNorm = Quality.normalize(preferred);
    final chain = Quality.fallbackChain(prefNorm);
    final result = <QualityOption>[];

    for (final q in chain) {
      final match = options.where((o) => o.value == q).toList();
      if (match.isNotEmpty) {
        result.add(match.first);
      }
    }

    // Privilege 没有数据时用 fallbackHash 构建最低保证
    if (result.isEmpty && fallbackHash != null && fallbackHash.isNotEmpty) {
      result.add(QualityOption(
        value: '128',
        hash: fallbackHash,
        label: Quality.labels['128']!,
      ));
    }

    return result;
  }

  /// 从 /privilege/lite 的 data 列表中提取 quality → hash 映射
  Map<String, String> toQualityHashMap() {
    final map = <String, String>{};
    for (final opt in options) {
      map[opt.value] = opt.hash;
    }
    return map;
  }
}

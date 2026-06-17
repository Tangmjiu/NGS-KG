// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/services.dart' show rootBundle;

/// 从 assets/config/preview.yaml 读取 preview 标记
///
/// 在 main() 启动时调用 [load()] 完成加载。
class PreviewConfig {
  PreviewConfig._();

  static bool _loaded = false;
  static bool _enabled = false;

  /// 是否已加载
  static bool get isLoaded => _loaded;

  /// preview 开关状态（未加载时默认为 false）
  static bool get enabled => _enabled;

  /// 异步加载 preview.yaml
  static Future<void> load() async {
    if (_loaded) return;
    try {
      final yaml = await rootBundle.loadString('assets/config/preview.yaml');
      _enabled = yaml.contains('enable_preview: true');
    } catch (_) {
      // 文件不存在或读取失败 → preview 关闭
      _enabled = false;
    }
    _loaded = true;
  }
}

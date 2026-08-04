import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// 系统均衡器服务
///
/// 通过 MethodChannel 与 Android 原生 EqualizerHelper 通信，
/// 控制 Android 系统内置均衡器的各频段增益。
///
/// 非 Android 平台所有方法返回空值/空列表。
class EqualizerService {
  static const _channel = MethodChannel('com.mjiutang.ngskg/equalizer');

  static final EqualizerService instance = EqualizerService._();
  EqualizerService._();

  bool _initialized = false;
  int _numberOfBands = 0;
  double _minBandLevel = 0;
  double _maxBandLevel = 0;

  bool get isAvailable => _initialized && _numberOfBands > 0;
  int get numberOfBands => _numberOfBands;
  double get minBandLevel => _minBandLevel;
  double get maxBandLevel => _maxBandLevel;

  /// 初始化：查询均衡器信息
  Future<void> init() async {
    try {
      final range =
          await _channel.invokeMethod<List<dynamic>>('getBandLevelRange');
      final bands = await _channel.invokeMethod<int>('getNumberOfBands');
      if (range != null && range.length == 2 && bands != null) {
        _minBandLevel = (range[0] as num).toDouble();
        _maxBandLevel = (range[1] as num).toDouble();
        _numberOfBands = bands;
        _initialized = true;
      }
    } catch (_) {
      _initialized = false;
    }
  }

  /// 获取指定频段的中心频率（Hz）
  Future<int> getCenterFreq(int band) async {
    try {
      final freq =
          await _channel.invokeMethod<int>('getCenterFreq', {'band': band});
      // 返回的是 mHz，转为 Hz
      return (freq ?? 0) ~/ 1000;
    } catch (_) {
      return 0;
    }
  }

  /// 设置指定频段的增益（毫分贝）
  Future<void> setBandLevel(int band, double levelMb) async {
    try {
      await _channel.invokeMethod('setBandLevel', {
        'band': band,
        'level': levelMb.round(),
      });
    } catch (_) {}
  }

  /// 获取指定频段的当前增益（毫分贝）
  Future<double> getBandLevel(int band) async {
    try {
      final level =
          await _channel.invokeMethod<int>('getBandLevel', {'band': band});
      return (level ?? 0).toDouble();
    } catch (_) {
      return 0;
    }
  }

  /// 释放均衡器资源
  Future<void> release() async {
    try {
      await _channel.invokeMethod('release');
    } catch (_) {}
    _initialized = false;
  }
}

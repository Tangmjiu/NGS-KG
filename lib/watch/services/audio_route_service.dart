// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 音频输出设备服务 — 枚举/监听/切换音频输出（手表喇叭、A2DP 蓝牙等）

import 'dart:async';

import 'package:flutter/services.dart';

/// 音频输出设备描述。
class AudioOutputDevice {
  /// 原生 AudioDeviceInfo.id
  final int id;

  /// 展示名称（蓝牙设备名 / 「手表扬声器」）
  final String name;

  /// 类型：`speaker` / `bluetooth` / `wired` / `other`
  final String type;

  /// 是否为当前媒体输出
  final bool isActive;

  /// 蓝牙设备电量百分比（0–100），不可用为 null
  final int? batteryLevel;

  const AudioOutputDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.isActive,
    this.batteryLevel,
  });

  factory AudioOutputDevice.fromMap(Map<Object?, Object?> map) {
    return AudioOutputDevice(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: (map['name'] as String?) ?? '未知设备',
      type: (map['type'] as String?) ?? 'other',
      isActive: (map['isActive'] as bool?) ?? false,
      batteryLevel: (map['batteryLevel'] as num?)?.toInt(),
    );
  }
}

/// 音频输出路由服务。
///
/// - [getDevices] 枚举当前可用输出设备
/// - [setDevice] 请求切换媒体输出（仅系统支持时生效）
/// - [devicesChanged] 设备插拔 / 蓝牙连接断开 / 当前路由变化事件流
///
/// 通道与原生 `AudioRouteManager` 对应；通道不可用（非 Android 或
/// 旧版本未注册）时所有方法安全降级为空。
class AudioRouteService {
  AudioRouteService._();
  static final AudioRouteService instance = AudioRouteService._();

  static const _method = MethodChannel('com.mjiutang.ngskg/audio_route');
  static const _events = EventChannel('com.mjiutang.ngskg/audio_route_events');

  Stream<void>? _devicesChangedStream;

  /// 设备变化事件（每次原生侧检测到路由变化时触发一次）。
  Stream<void> get devicesChanged {
    return _devicesChangedStream ??= _events
        .receiveBroadcastStream()
        .map((_) {})
        .handleError((_) {})
        .asBroadcastStream();
  }

  /// 枚举当前可用输出设备。失败返回空列表。
  Future<List<AudioOutputDevice>> getDevices() async {
    try {
      final list = await _method.invokeListMethod<dynamic>('getAudioOutputs');
      if (list == null) return const [];
      return list
          .whereType<Map>()
          .map(AudioOutputDevice.fromMap)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// 请求切换媒体输出到指定设备。
  ///
  /// 返回 true 表示系统已接受并生效；返回 false 表示系统不支持
  /// 程序化切换（调用方应打开系统选择器或提示用户）。
  Future<bool> setDevice(int deviceId) async {
    try {
      final ok = await _method
          .invokeMethod<bool>('setAudioOutput', {'deviceId': deviceId});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 打开系统媒体输出选择面板（setDevice 不可用时的兜底）。
  Future<void> openSystemSwitcher() async {
    try {
      await _method.invokeMethod<void>('showSystemOutputSwitcher');
    } catch (_) {}
  }
}

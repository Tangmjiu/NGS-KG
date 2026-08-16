// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/logger.dart';

/// 完整日志导出服务（手表版）。
///
/// 在「设置 → 关于」中隐藏入口触发，导出一个纯文本日志文件，内容包含：
/// 1. 设备 / 应用信息头（型号、Android 版本、SDK、包名、应用版本、导出时间）
/// 2. Android logcat（本进程，尽力读取；受 READ_LOGS 限制可能为空或提示）
/// 3. 内存中的 Flutter 日志环形缓冲（Log.entries，含 FlutterError / 平台错误）
/// 4. 磁盘上的历史日志文件（app_YYYYMMDD.log）
///
/// 导出文件写入 {appDocDir}/logs/ngskg_watch_log_<时间戳>.txt，
/// 返回文件路径，供 UI 展示 / 通过 adb pull 取回。
class LogExportService {
  LogExportService._();
  static final LogExportService instance = LogExportService._();

  static const _channel = MethodChannel('com.mjiutang.ngskg/log_export');

  /// 导出完整日志，返回文件路径。
  Future<String> export() async {
    final sb = StringBuffer();

    // ── 1. 头部信息 ──
    sb.writeln('=' * 60);
    sb.writeln('NGS-KG+ Watch 完整日志导出');
    sb.writeln('导出时间: ${DateTime.now().toIso8601String()}');
    sb.writeln('=' * 60);

    try {
      final info = await PackageInfo.fromPlatform();
      sb.writeln('应用版本: ${info.version}+${info.buildNumber}');
      sb.writeln('包名: ${info.packageName}');
    } catch (e) {
      sb.writeln('应用版本: 读取失败 ($e)');
    }

    try {
      final dev =
          await _channel.invokeMapMethod<String, dynamic>('getDeviceInfo');
      if (dev != null) {
        sb.writeln('设备型号: ${dev['manufacturer']} ${dev['model']}');
        sb.writeln('设备代号: ${dev['device']} (${dev['product']})');
        sb.writeln('Android: ${dev['androidVersion']} (SDK ${dev['sdkInt']})');
        sb.writeln('架构: ${dev['abi']}');
        sb.writeln('硬件: ${dev['hardware']}');
      } else {
        sb.writeln('设备信息: 读取失败 (原生通道返回 null)');
      }
    } catch (e) {
      sb.writeln('设备信息: 读取失败 ($e)');
    }
    sb.writeln('');

    // ── 2. Android logcat ──
    sb.writeln('=' * 60);
    sb.writeln('Android logcat (本进程)');
    sb.writeln('=' * 60);
    try {
      final logcat = await _channel.invokeMethod<String>('dumpLogcat');
      sb.writeln(logcat ?? '(logcat 返回 null)');
    } catch (e, s) {
      sb.writeln('logcat 读取异常: $e');
      sb.writeln(s.toString().split('\n').take(8).join('\n'));
    }
    sb.writeln('');

    // ── 3. Flutter 内存日志环形缓冲 ──
    sb.writeln('=' * 60);
    sb.writeln('Flutter 内存日志 (Log.entries，最近 ${Log.entries.length} 条)');
    sb.writeln('=' * 60);
    try {
      final entries = Log.entries;
      if (entries.isEmpty) {
        sb.writeln('(无内存日志)');
      } else {
        for (final e in entries) {
          sb.writeln(e.formatted);
        }
      }
    } catch (e, s) {
      sb.writeln('内存日志读取异常: $e\n$s');
    }
    sb.writeln('');

    // ── 4. 磁盘历史日志文件 ──
    sb.writeln('=' * 60);
    sb.writeln('磁盘日志文件 (app_YYYYMMDD.log)');
    sb.writeln('=' * 60);
    try {
      await Log.flush();
      final files = await Log.logFiles();
      if (files.isEmpty) {
        sb.writeln('(未找到日志文件)');
      } else {
        for (final f in files) {
          sb.writeln('');
          sb.writeln('── 文件: ${f.path} ──');
          try {
            final content = await f.readAsString();
            sb.writeln(content);
          } catch (e) {
            sb.writeln('读取失败: $e');
          }
        }
      }
    } catch (e, s) {
      sb.writeln('磁盘日志读取异常: $e\n$s');
    }
    sb.writeln('');
    sb.writeln('=' * 60);
    sb.writeln('导出结束');
    sb.writeln('=' * 60);

    // ── 写入导出文件 ──
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${dir.path}/logs');
    if (!await logDir.exists()) await logDir.create(recursive: true);
    final now = DateTime.now();
    final stamp =
        '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    final out = File('${logDir.path}/ngskg_watch_log_$stamp.txt');
    await out.writeAsString(sb.toString(), flush: true);
    Log.i('LogExport', '日志已导出: ${out.path}');
    return out.path;
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}

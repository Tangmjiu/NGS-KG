// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT
//
// 日志导出页 — 导出完整日志并指导用户取回文件

import 'package:flutter/material.dart';

import '../../services/log_export_service.dart';
import '../utils/watch_layout.dart';
import '../utils/watch_motion.dart';
import '../widgets/watch_scaffold.dart';

/// 日志导出界面。
///
/// 用户点击「导出日志」后生成一个包含 logcat + Flutter 日志的文本文件，
/// 随后界面展示文件路径和三种取回方式（电脑 / 手机 / 平板）。
class WatchLogExportScreen extends StatefulWidget {
  const WatchLogExportScreen({super.key});

  @override
  State<WatchLogExportScreen> createState() => _WatchLogExportScreenState();
}

class _WatchLogExportScreenState extends State<WatchLogExportScreen> {
  bool _exporting = false;
  String? _exportedPath;

  Future<void> _export() async {
    if (_exporting) return;
    WatchMotion.confirm();
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await LogExportService.instance.export();
      if (!mounted) return;
      setState(() => _exportedPath = path);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('日志已导出'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e, s) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('导出失败: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
      debugPrint('LogExport failed: $e\n$s');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = WatchLayout.of(context);
    final cs = Theme.of(context).colorScheme;

    return WatchScaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          layout.listHorizontal,
          4,
          layout.listHorizontal,
          layout.bottomInset + 16,
        ),
        children: [
          // ── 标题 ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: Text(
                '日志导出',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // ── 导出按钮 ──
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _exporting ? null : _export,
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bug_report_outlined, size: 18),
                label: Text(_exporting ? '正在导出…' : '导出完整日志'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
          ),

          // ── 导出结果 ──
          if (_exportedPath != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      Text(
                        '导出成功',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _exportedPath!,
                    style: TextStyle(
                      fontSize: 9,
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            // ── 取回指引 ──
            _InstructionHeader(text: '如何取回日志', cs: cs),
            const SizedBox(height: 4),

            _InstructionCard(
              icon: Icons.computer_rounded,
              title: '电脑 / 平板',
              steps: const [
                '1. 手表开启「设置 → 开发者选项 → 无线调试」或 USB 调试',
                '2. 电脑安装 adb 工具（Android Platform Tools）',
                '3. 执行以下命令复制日志到电脑：',
              ],
              code: _exportedPath != null
                  ? 'adb pull "$_exportedPath"'
                  : 'adb pull <日志路径>',
              cs: cs,
            ),
            const SizedBox(height: 6),

            _InstructionCard(
              icon: Icons.phone_android_rounded,
              title: '手机',
              steps: const [
                '1. 手机安装支持 adb 的工具：',
                '   - 甲壳虫ADB助手（应用商店搜索，国内推荐）',
                '   - LADB / Bugjaeger（国际版可选）',
                '2. 手表开启「设置 → 开发者选项 → 无线调试」',
                '3. 在 adb 工具中连接手表（扫码或输入 IP:端口）',
                '4. 连接成功后执行以下命令：',
              ],
              code: _exportedPath != null
                  ? 'adb pull "$_exportedPath"'
                  : 'adb pull <日志路径>',
              cs: cs,
            ),
            const SizedBox(height: 6),

            _InstructionCard(
              icon: Icons.usb_rounded,
              title: 'USB 数据线',
              steps: const [
                '1. 用数据线将手表连接到电脑',
                '2. 电脑识别为 MTP 设备后在文件管理器中找到：',
                '3. 内部存储 → Android → data → com.mjiutang.ngskg.wear',
              ],
              code: null,
              cs: cs,
            ),
            const SizedBox(height: 6),

            // ── 提示 ──
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: cs.onSurface.withValues(alpha: 0.6)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '日志包含设备信息、Android logcat 和 Flutter 运行日志，'
                      '导出后发送给开发者即可帮助排查问题。',
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurface.withValues(alpha: 0.6),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── 未导出时的说明 ──
          if (_exportedPath == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                '点击上方按钮导出完整日志文件，'
                '包含设备信息、logcat 和 Flutter 运行日志，'
                '用于向开发者反馈问题。',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.5),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

/// 指引小标题。
class _InstructionHeader extends StatelessWidget {
  final String text;
  final ColorScheme cs;

  const _InstructionHeader({required this.text, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: cs.onSurface.withValues(alpha: 0.7),
        letterSpacing: 0.3,
      ),
    );
  }
}

/// 指引卡片 — 图标 + 标题 + 步骤 + 可选命令。
class _InstructionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> steps;
  final String? code;
  final ColorScheme cs;

  const _InstructionCard({
    required this.icon,
    required this.title,
    required this.steps,
    this.code,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                step,
                style: TextStyle(
                  fontSize: 9.5,
                  color: cs.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
            ),
          if (code != null) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                code!,
                style: TextStyle(
                  fontSize: 9,
                  fontFamily: 'monospace',
                  color: cs.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../services/log_export_service.dart';
import '../utils/watch_motion.dart';
import 'login_screen.dart';

class WatchLogExportScreen extends StatefulWidget {
  const WatchLogExportScreen({super.key});
  @override
  State<WatchLogExportScreen> createState() => _WatchLogExportScreenState();
}

class _WatchLogExportScreenState extends State<WatchLogExportScreen> {
  bool _exporting = false;
  bool _failed = false;
  String? _path;

  Future<void> _export() async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _failed = false;
    });
    try {
      final path = await LogExportService.instance.export();
      if (!mounted) return;
      setState(() => _path = path);
      if (ModalRoute.of(context)?.isCurrent == true) WatchMotion.confirm();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    if (path != null) {
      return WatchFlowPage(
        key: const ValueKey('success'),
        title: '导出成功',
        center: true,
        symbol: Icon(
          Icons.check_rounded,
          size: 42,
          color: Theme.of(context).colorScheme.primary,
        ),
        children: [
          FilledButton.tonal(
            onPressed: () {
              if (ModalRoute.of(context)?.isCurrent != true) return;
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => _LogLocation(path: path),
                ),
              );
            },
            child: const Text('查看保存位置'),
          ),
        ],
      );
    }
    return WatchFlowPage(
      title: '导出日志',
      center: true,
      children: [
        Semantics(
          liveRegion: _failed,
          child: Text(
            _failed ? '没能保存日志，请重试。' : '日志保存在手表上。分享前请检查其中的个人信息。',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _exporting ? null : _export,
          child: Text(
            _exporting
                ? '正在导出…'
                : _failed
                ? '重新导出'
                : '导出完整日志',
          ),
        ),
      ],
    );
  }
}

class _LogLocation extends StatelessWidget {
  const _LogLocation({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final privateApp = RegExp(
      r'^/data/(?:user(?:_de)?/\d+|data)/([\w.]+)/',
    ).firstMatch(path);
    return WatchFlowPage(
      title: '保存位置',
      children: [
        SelectableText(path),
        const SizedBox(height: 10),
        if (privateApp == null) ...[
          const Text('用 USB 或无线调试连接手表后，可用 ADB 取回文件。'),
          const SizedBox(height: 6),
          SelectableText('adb pull "$path"'),
        ] else ...[
          const Text('文件位于应用私有目录。使用调试版时，可以连接 ADB，把日志保存到电脑。'),
          const SizedBox(height: 6),
          SelectableText(
            'adb exec-out run-as ${privateApp.group(1)} cat "$path" > watch-log.txt',
          ),
        ],
      ],
    );
  }
}

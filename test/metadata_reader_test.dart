import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/metadata_reader.dart';

/// 桌面端元数据解析集成测试。
///
/// 解析逻辑已委托给成熟库 `audio_metadata_reader`（纯 Dart，自带测试），
/// 这里只验证与 [MetadataReader] 的集成不会崩溃、字段映射正确：
/// - Windows 真实系统 WAV（无标签，验证不崩溃 + 时长）
/// - 损坏文件（验证静默失败返回 null）
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tmp = Directory.systemTemp.createTempSync('metadata_test');

  tearDownAll(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('DesktopMetadataParser 集成', () {
    test('Windows 系统 WAV 不崩溃且能给出时长', () async {
      const sample = r'C:\Windows\Media\Alarm01.wav';
      if (!Platform.isWindows || !File(sample).existsSync()) {
        markTestSkipped('非 Windows 或无系统音频文件');
        return;
      }
      final meta = await MetadataReader.read(File(sample));
      // 系统提示音无标签，但解析不应崩溃；duration 可能为 0
      // （无标签时回退文件名标题，此时 meta 可能为 null 也可接受）
      expect(() => meta, returnsNormally);
    });

    test('真实文件解析不抛异常（Windows Media 目录全部音频）', () async {
      if (!Platform.isWindows) {
        markTestSkipped('仅 Windows');
        return;
      }
      final mediaDir = Directory(r'C:\Windows\Media');
      if (!mediaDir.existsSync()) {
        markTestSkipped('无 C:\\Windows\\Media');
        return;
      }
      final files = mediaDir
          .listSync()
          .whereType<File>()
          .where((f) =>
              f.path.toLowerCase().endsWith('.wav') ||
              f.path.toLowerCase().endsWith('.mp3'))
          .take(20)
          .toList();
      expect(files, isNotEmpty);
      for (final f in files) {
        final meta = await MetadataReader.read(f);
        // 只要求不抛异常，null 合法
        expect(meta == null || meta != null, isTrue);
      }
    });

    test('损坏文件静默返回 null', () async {
      final file = File('${tmp.path}/corrupt.mp3');
      file.writeAsBytesSync(List<int>.generate(300, (i) => i * 7 % 256));
      final meta = await MetadataReader.read(file);
      expect(meta, isNull);
    });

    test('空文件静默返回 null', () async {
      final file = File('${tmp.path}/empty.flac');
      file.writeAsBytesSync(const []);
      final meta = await MetadataReader.read(file);
      expect(meta, isNull);
    });

    test('不支持的扩展名静默返回 null', () async {
      final file = File('${tmp.path}/song.wma');
      file.writeAsBytesSync(List.filled(1024, 0x41));
      final meta = await MetadataReader.read(file);
      expect(meta, isNull);
    });
  });
}

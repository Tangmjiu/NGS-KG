// 检查 pubspec.yaml 里声明的直接依赖是否真的被 lib/ 和 test/ 使用，
// 以及代码里 import 的包是否都声明过。CI 中未使用依赖会导致失败。
import 'dart:io';

const _sdkAndTooling = <String>{
  'flutter',
  'flutter_test',
  'flutter_lints',
  // 只在 pubspec 配置段用，不会被 Dart 代码 import
  'flutter_launcher_icons',
};

Future<void> main() async {
  final root = Directory.current;
  final pubspec = File('${root.path}/pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('找不到 pubspec.yaml，请在项目根目录运行');
    exit(2);
  }

  final declared = _declaredDependencies(pubspec.readAsLinesSync());
  final selfName = _declaredPackageName(pubspec.readAsLinesSync());
  final imported = _importedPackages(root)..remove(selfName);

  final unused = declared.difference(imported).difference(_sdkAndTooling);
  final missing = imported
      .where((p) => !p.startsWith('dart:'))
      .toSet()
      .difference(declared)
      .difference(_sdkAndTooling);

  if (unused.isEmpty && missing.isEmpty) {
    stdout.writeln('依赖检查通过：${declared.length} 个直接依赖都在使用');
    return;
  }

  if (unused.isNotEmpty) {
    stderr.writeln('以下直接依赖没有被 lib/ 或 test/ 引用，请从 pubspec.yaml 删除：');
    for (final name in unused.toList()..sort()) {
      stderr.writeln('  - $name');
    }
  }
  if (missing.isNotEmpty) {
    stderr.writeln('以下包在代码中被 import，但 pubspec.yaml 没有声明：');
    for (final name in missing.toList()..sort()) {
      stderr.writeln('  - $name');
    }
  }
  exit(1);
}

String _declaredPackageName(List<String> lines) {
  for (final line in lines) {
    final match = RegExp(r'^name:\s*([a-z0-9_]+)').firstMatch(line);
    if (match != null) return match.group(1)!;
  }
  return '';
}

Set<String> _declaredDependencies(List<String> lines) {
  final result = <String>{};
  String? section;
  for (final line in lines) {
    if (line.startsWith('dependencies:')) {
      section = 'dependencies:';
      continue;
    }
    if (line.startsWith('dev_dependencies:')) {
      section = 'dev_dependencies:';
      continue;
    }
    if (section == null) continue;
    // 段落结束：顶格的非空行
    if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) {
      section = null;
      continue;
    }
    final match = RegExp(r'^ {2}([a-z0-9_]+):').firstMatch(line);
    if (match != null) result.add(match.group(1)!);
  }
  return result;
}

Set<String> _importedPackages(Directory root) {
  final imported = <String>{};
  final pattern = RegExp(r'''package:([a-zA-Z0-9_]+)/''');
  for (final dirName in ['lib', 'test', 'integration_test']) {
    final dir = Directory('${root.path}/$dirName');
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final match in pattern.allMatches(entity.readAsStringSync())) {
        imported.add(match.group(1)!);
      }
    }
  }
  return imported;
}

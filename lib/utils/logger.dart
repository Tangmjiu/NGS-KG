import 'dart:io';
import 'dart:developer' as dev;
import 'package:path_provider/path_provider.dart';

class Log {
  Log._();

  static Log? _instance;
  File? _logFile;
  IOSink? _sink;
  bool _ready = false;
  final List<String> _buffer = [];

  static Future<void> init() async {
    final log = Log._();
    _instance = log;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      final now = DateTime.now();
      final date =
          '${now.year}${_pad(now.month)}${_pad(now.day)}';
      log._logFile = File('${logDir.path}/app_$date.log');
      log._sink = log._logFile!.openWrite(mode: FileMode.append);
      log._ready = true;
      for (final line in log._buffer) {
        log._sink!.writeln(line);
      }
      log._buffer.clear();
      _cleanOldLogs(logDir);
    } catch (_) {}
  }

  static void _cleanOldLogs(Directory dir) async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      final files = dir.listSync();
      for (final f in files) {
        if (f is File) {
          final stat = f.statSync();
          if (stat.changed.millisecondsSinceEpoch <
              cutoff.millisecondsSinceEpoch) {
            f.deleteSync();
          }
        }
      }
    } catch (_) {}
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static void d(String tag, String message) {
    _log('D  ', tag, message);
  }

  static void i(String tag, String message) {
    _log('I  ', tag, message);
  }

  static void w(String tag, String message,
      [Object? error, StackTrace? stack]) {
    _log('W  ', tag, message, error, stack);
  }

  static void e(String tag, String message,
      [Object? error, StackTrace? stack]) {
    _log('E  ', tag, message, error, stack);
  }

  static void _log(String level, String tag, String message,
      [Object? error, StackTrace? stack]) {
    final now = DateTime.now();
    final ts =
        '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}.${now.millisecond.toString().padLeft(3, '0')}';
    final line = '$ts $level [$tag] $message';

    // Console — use print() so Android logcat captures it in both debug & release
    print(line);
    if (error != null) print('  CAUSE: $error');
    if (stack != null) {
      final compressed = stack.toString().split('\n').take(6).join('\n');
      print('  STACK: $compressed');
    }

    // DevTools
    dev.log(
      message,
      name: tag,
      level: level.trim() == 'E'
          ? 1000
          : level.trim() == 'W'
              ? 900
              : level.trim() == 'I'
                  ? 800
                  : 500,
      error: error,
      stackTrace: stack,
    );

    // File
    final sb = StringBuffer(line);
    if (error != null) sb.write('\n  CAUSE: $error');
    if (stack != null) {
      sb.write('\n  STACK: ${stack.toString().split('\n').take(6).join('\n')}');
    }
    _instance?._write(sb.toString());
  }

  void _write(String line) {
    if (_ready && _sink != null) {
      _sink!.writeln(line);
      _sink!.flush();
    } else if (!_ready) {
      _buffer.add(line);
    }
  }
}

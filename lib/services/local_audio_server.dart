// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:io';

import '../utils/logger.dart';

/// 本机本地文件 HTTP 桥（Windows 专用）。
///
/// just_audio_windows 的 `MediaSource::CreateFromUri` 只支持 http(s) 源，
/// 对 `file://` 一律报 sourceNotSupported，导致本地音乐无法播放。
/// 本服务把本地音频文件以 `http://127.0.0.1:<port>/audio?path=...` 暴露给
/// 播放器，走与在线歌曲相同的 HTTP 流播放路径（支持 Range 拖动进度）。
///
/// 只监听回环地址，不对外开放；仅服务显式传入的绝对路径。
class LocalAudioServer {
  LocalAudioServer._();

  static final LocalAudioServer instance = LocalAudioServer._();

  HttpServer? _server;
  int _port = 0;

  /// 返回指定本地文件的播放 URL（首次调用时启动服务）。
  Future<String> urlForPath(String path) async {
    await _ensureStarted();
    return 'http://127.0.0.1:$_port/audio?path=${Uri.encodeQueryComponent(path)}';
  }

  Future<void> _ensureStarted() async {
    if (_server != null) return;
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server = server;
      _port = server.port;
      server.listen(_handleRequest, onError: (Object e, StackTrace s) {
        Log.w('local_audio_server', 'connection error', e, s);
      });
      Log.i('local_audio_server', 'started on 127.0.0.1:$_port');
    } catch (e, s) {
      Log.e('local_audio_server', 'bind failed', e, s);
      rethrow;
    }
  }

  void _handleRequest(HttpRequest request) {
    request.response.headers.set(HttpHeaders.cacheControlHeader,
        'no-store, no-cache, must-revalidate');
    request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    request.response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
    try {
      if (request.method != 'GET' && request.method != 'HEAD') {
        request.response.statusCode = HttpStatus.methodNotAllowed;
        request.response.close();
        return;
      }
      if (request.uri.path != '/audio') {
        request.response.statusCode = HttpStatus.notFound;
        request.response.close();
        return;
      }
      final raw = request.uri.queryParameters['path'];
      if (raw == null || raw.isEmpty) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.close();
        return;
      }
      final file = File(raw);
      if (!file.existsSync() || !file.isAbsolute) {
        request.response.statusCode = HttpStatus.notFound;
        request.response.close();
        return;
      }
      final total = file.lengthSync();
      if (total <= 0) {
        request.response.statusCode = HttpStatus.notFound;
        request.response.close();
        return;
      }

      request.response.headers
          .set(HttpHeaders.contentTypeHeader, _mimeFor(file.path));

      // 解析 Range 头（仅单区间，用于播放器 seek / 预加载）
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      int start = 0;
      int? end;
      var partial = false;
      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        final match = RegExp(r'^(\d*)-(\d*)$')
            .firstMatch(rangeHeader.substring(6).trim());
        if (match != null) {
          final s = match.group(1);
          final e = match.group(2);
          if (s != null && s.isNotEmpty && s != '0') {
            start = int.tryParse(s) ?? 0;
            partial = true;
          }
          if (e != null && e.isNotEmpty) end = int.tryParse(e);
        }
      }
      if (start >= total) {
        // 起始超出文件末尾:416
        request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        request.response.headers.set(
            HttpHeaders.contentRangeHeader, 'bytes */$total');
        request.response.close();
        return;
      }
      end ??= total - 1;
      if (end >= total) end = total - 1;

      request.response.headers
          .set(HttpHeaders.contentLengthHeader, (end - start + 1).toString());
      if (partial) {
        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers
            .set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$total');
      } else {
        request.response.statusCode = HttpStatus.ok;
      }

      if (request.method == 'HEAD') {
        request.response.close();
        return;
      }
      final stream = file.openRead(start, end + 1);
      request.response.addStream(stream).whenComplete(() {
        request.response.close();
      }).catchError((Object e) {
        request.response.close();
      });
    } catch (e, s) {
      Log.e('local_audio_server', 'serve error: ${request.uri}', e, s);
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.close();
      } catch (_) {}
    }
  }

  static String _mimeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.flac')) return 'audio/flac';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.wma')) return 'audio/x-ms-wma';
    return 'application/octet-stream';
  }
}

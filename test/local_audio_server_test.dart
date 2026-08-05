import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/services/local_audio_server.dart';

void main() {
  test('LocalAudioServer serves files with Range support', () async {
    final dir = Directory.systemTemp.createTempSync('las_test');
    final file = File('${dir.path}/test-song.mp3');
    final data = Uint8List.fromList(List.generate(100000, (i) => i % 256));
    await file.writeAsBytes(data);

    final url = await LocalAudioServer.instance.urlForPath(file.path);

    Future<Uint8List> readAll(HttpClientResponse r) =>
        r.fold<Uint8List>(Uint8List(0), (a, c) {
          final n = Uint8List(a.length + c.length);
          n.setRange(0, a.length, a);
          n.setRange(a.length, n.length, c);
          return n;
        });

    // 完整请求
    final full = await HttpClient()
        .getUrl(Uri.parse(url))
        .then((r) => r.close());
    final fullBytes = await readAll(full);
    expect(full.statusCode, 200);
    expect(fullBytes.length, 100000);
    expect(full.headers.value('accept-ranges'), 'bytes');

    // Range 请求（播放器 seek 依赖）
    final range = await HttpClient().getUrl(Uri.parse(url)).then((r) {
      r.headers.set(HttpHeaders.rangeHeader, 'bytes=50000-59999');
      return r.close();
    });
    final rangeBytes = await readAll(range);
    print('RANGE RESP: status=${range.statusCode} headers=${range.headers}');
    expect(range.statusCode, 206);
    expect(rangeBytes.length, 10000);
    expect(rangeBytes[0], data[50000]);
    expect(range.headers.value('content-range'), 'bytes 50000-59999/100000');

    // 尾部 open Range
    final tail = await HttpClient().getUrl(Uri.parse(url)).then((r) {
      r.headers.set(HttpHeaders.rangeHeader, 'bytes=99999-');
      return r.close();
    });
    final tailBytes = await readAll(tail);
    expect(tail.statusCode, 206);
    expect(tailBytes.length, 1);
    expect(tail.headers.value('content-range'), 'bytes 99999-99999/100000');

    // 超出范围 → 416
    final overflow = await HttpClient().getUrl(Uri.parse(url)).then((r) {
      r.headers.set(HttpHeaders.rangeHeader, 'bytes=200000-');
      return r.close();
    });
    await readAll(overflow);
    expect(overflow.statusCode, 416);

    // 不存在的文件 → 404
    final missing = await HttpClient()
        .getUrl(Uri.parse(
            'http://127.0.0.1:${Uri.parse(url).port}/audio?path=${Uri.encodeQueryComponent('Z:/nope/x.mp3')}'))
        .then((r) => r.close());
    await readAll(missing);
    expect(missing.statusCode, 404);
  });
}

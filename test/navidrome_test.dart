// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/navidrome/navidrome_config.dart';
import 'package:ngskg_plus/navidrome/navidrome_models.dart';
import 'package:ngskg_plus/navidrome/navidrome_provider.dart';
import 'package:ngskg_plus/navidrome/navidrome_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNavidromeService extends NavidromeService {
  final queries = <String>[];
  final searches = <Completer<List<SubsonicSong>>>[];
  final searchTokens = <CancelToken?>[];
  bool pingResult = true;
  bool throwOnConfigure = false;
  int streamUrlCalls = 0;
  Completer<void>? pingStarted;

  @override
  void configure(String baseUrl, String username, String password) {
    if (throwOnConfigure) throw StateError('配置失败');
    super.configure(baseUrl, username, password);
  }

  @override
  Future<bool> ping() async {
    final started = pingStarted;
    if (started != null && !started.isCompleted) started.complete();
    return pingResult;
  }

  @override
  Future<List<SubsonicArtist>> getArtists() async => [];

  @override
  Future<List<SubsonicSong>> getAlbumSongs(String albumId) async => [
        SubsonicSong(id: albumId, title: albumId, coverArt: 'cover'),
      ];

  @override
  Future<List<SubsonicSong>> search(String query,
      {CancelToken? cancelToken}) {
    queries.add(query);
    searchTokens.add(cancelToken);
    final completer = Completer<List<SubsonicSong>>();
    searches.add(completer);
    // 故意不响应 cancel，验证迟到结果仍被请求版本拦截。
    return completer.future;
  }

  @override
  String getStreamUrl(String songId) {
    streamUrlCalls++;
    return super.getStreamUrl(songId);
  }
}

class _ControlledNavidromeConfig implements NavidromeConfig {
  String? url;
  String? username;
  String? password;
  Completer<void>? clearPaused;
  Completer<void>? clearStarted;

  @override
  Future<void> setServerUrl(String value) async => url = value;

  @override
  Future<void> setUsername(String value) async => username = value;

  @override
  Future<void> setPassword(String value) async => password = value;

  @override
  Future<void> clear() async {
    url = null;
    final paused = clearPaused;
    if (paused != null) {
      clearStarted!.complete();
      await paused.future;
    }
    username = null;
    password = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Navidrome 封面会话缓存', () {
    test('同一会话 URL 稳定，重连刷新签名且账号/服务器隔离', () {
      final service = NavidromeService();
      addTearDown(service.dispose);
      service.configure('https://first.invalid/music/', 'alice', 'secret');
      final first = service.getCoverArtUrl('cover & 1')!;
      expect(service.getCoverArtUrl('cover & 1'), first);
      final uri = Uri.parse(first);
      expect(uri.path, '/music/rest/getCoverArt');
      expect(uri.queryParameters['id'], 'cover & 1');
      expect(uri.queryParameters['u'], 'alice');
      expect(uri.queryParameters['t'],
          md5.convert(utf8.encode('secret${uri.queryParameters['s']}')).toString());

      service.configure('https://first.invalid/music/', 'alice', 'secret');
      expect(service.getCoverArtUrl('cover & 1'), isNot(first));
      service.configure('https://second.invalid', 'bob', 'different');
      final second = Uri.parse(service.getCoverArtUrl('cover & 1')!);
      expect(second.host, 'second.invalid');
      expect(second.queryParameters['u'], 'bob');
      expect(second.queryParameters['t'],
          md5.convert(utf8.encode('different${second.queryParameters['s']}')).toString());
      service.dispose();
      expect(service.isConfigured, isFalse);
      expect(service.getCoverArtUrl('cover & 1'), isNull);
    });
  });

  group('Navidrome 请求生命周期', () {
    testWidgets('连续输入只搜索最后一次，完成后停止 loading', (tester) async {
      final service = _FakeNavidromeService();
      final provider = NavidromeProvider(service: service);
      addTearDown(provider.dispose);
      expect(await provider.connect('https://music.invalid', 'user', 'pass'), isTrue);

      final first = provider.search('a');
      await tester.pump(const Duration(milliseconds: 150));
      final latest = provider.search('ab');
      await first;
      await tester.pump(const Duration(milliseconds: 299));
      expect(service.queries, isEmpty);
      expect(provider.isSearching, isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      expect(service.queries, ['ab']);
      service.searches.single.complete([
        const SubsonicSong(id: 'ab', title: '结果'),
      ]);
      await tester.pump();
      await latest;
      expect(provider.isSearching, isFalse);
      expect(provider.searchResults.single.id, 'ab');
    });

    testWidgets('旧搜索不得覆盖新结果，清空后迟到结果不得回填', (tester) async {
      final service = _FakeNavidromeService();
      final provider = NavidromeProvider(service: service);
      addTearDown(provider.dispose);
      await provider.connect('https://music.invalid', 'user', 'pass');
      final old = provider.search('old');
      await tester.pump(const Duration(milliseconds: 300));
      final latest = provider.search('new');
      await old;
      expect(service.searchTokens.first!.isCancelled, isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      service.searches[1].complete([
        const SubsonicSong(id: 'new', title: '新结果'),
      ]);
      await tester.pump();
      await latest;
      service.searches[0].complete([
        const SubsonicSong(id: 'old', title: '旧结果'),
      ]);
      await tester.pump();
      expect(provider.searchResults.single.id, 'new');
      expect(provider.isSearching, isFalse);

      final cleared = provider.search('clear');
      await tester.pump(const Duration(milliseconds: 300));
      provider.clearSearch();
      await cleared;
      service.searches[2].complete([
        const SubsonicSong(id: 'clear', title: '已清空'),
      ]);
      await tester.pump();
      expect(provider.searchResults, isEmpty);
      expect(provider.isSearching, isFalse);
    });

    testWidgets('请求失败复位 loading 且仍可再次搜索', (tester) async {
      final service = _FakeNavidromeService();
      final provider = NavidromeProvider(service: service);
      addTearDown(provider.dispose);
      await provider.connect('https://music.invalid', 'user', 'pass');
      final failed = provider.search('error');
      await tester.pump(const Duration(milliseconds: 300));
      service.searches.single.completeError(StateError('请求失败'));
      await tester.pump();
      await failed;
      expect(provider.isSearching, isFalse);
      expect(provider.error, '搜索失败');

      final retry = provider.search('retry');
      await tester.pump(const Duration(milliseconds: 300));
      service.searches.last.complete([]);
      await tester.pump();
      await retry;
      expect(provider.isSearching, isFalse);
      expect(provider.error, isNull);
    });

    testWidgets('断连取消防抖并阻止正在执行的搜索回填', (tester) async {
      final service = _FakeNavidromeService();
      final provider = NavidromeProvider(service: service);
      addTearDown(provider.dispose);
      await provider.connect('https://music.invalid', 'user', 'pass');
      final pending = provider.search('pending');
      await provider.disconnect();
      await pending;
      await tester.pump(const Duration(milliseconds: 300));
      expect(service.queries, isEmpty);
      expect(provider.isSearching, isFalse);

      await provider.connect('https://music.invalid', 'other', 'pass');
      final running = provider.search('running');
      await tester.pump(const Duration(milliseconds: 300));
      await provider.disconnect();
      await running;
      service.searches.single.complete([
        const SubsonicSong(id: 'old-user', title: '旧账号结果'),
      ]);
      await tester.pump();
      expect(provider.searchResults, isEmpty);
      expect(provider.connected, isFalse);
    });

    test('配置异常也能复位 connecting，失败后允许重连', () async {
      final service = _FakeNavidromeService()..throwOnConfigure = true;
      final provider = NavidromeProvider(service: service);
      addTearDown(provider.dispose);
      expect(await provider.connect('https://music.invalid', 'user', 'pass'), isFalse);
      expect(provider.connecting, isFalse);
      service.throwOnConfigure = false;
      expect(await provider.connect('https://music.invalid', 'user', 'pass'), isTrue);
      await provider.disconnect();
      expect(await provider.connect('https://music.invalid', 'other', 'pass'), isTrue);
    });

    test('断连清理未完成时重连，旧清理不得删除新账号凭据', () async {
      final service = _FakeNavidromeService();
      final config = _ControlledNavidromeConfig();
      final provider = NavidromeProvider(service: service, config: config);
      addTearDown(provider.dispose);
      await provider.connect('https://first.invalid', 'alice', 'old-pass');
      config.clearStarted = Completer<void>();
      config.clearPaused = Completer<void>();
      final disconnect = provider.disconnect();
      await config.clearStarted!.future;
      expect(config.url, isNull);
      expect(config.username, 'alice');

      service.pingStarted = Completer<void>();
      final reconnect = provider.connect('https://second.invalid', 'bob', 'new-pass');
      await service.pingStarted!.future;
      // 让 ping 后续保存流程运行；正确实现此时应等待旧 clear 完成。
      for (var i = 0; i < 10; i++) {
        await Future<void>.value();
      }
      final connectedBeforeClear = provider.connected;
      config.clearPaused!.complete();
      await disconnect;
      expect(await reconnect, isTrue);
      expect(connectedBeforeClear, isFalse);
      expect(config.url, 'https://second.invalid');
      expect(config.username, 'bob');
      expect(config.password, 'new-pass');
    });

    test('播放模型仅按数据版本映射，切换账号不复用旧 URL', () async {
      final service = _FakeNavidromeService();
      final provider = NavidromeProvider(service: service);
      addTearDown(provider.dispose);
      await provider.connect('https://music.invalid', 'alice', 'pass');
      await provider.selectAlbum('album', '专辑');
      final first = provider.playbackSongs;
      expect(provider.playbackSongs, same(first));
      expect(service.streamUrlCalls, 1);
      await provider.connect('https://music.invalid', 'bob', 'pass');
      expect(provider.playbackSongs, isEmpty);
      await provider.selectAlbum('album', '专辑');
      final second = provider.playbackSongs;
      expect(second, isNot(same(first)));
      expect(Uri.parse(second.single.filePath!).queryParameters['u'], 'bob');
      expect(second.single.albumCoverUrl, isNot(first.single.albumCoverUrl));
      expect(service.streamUrlCalls, 2);
    });
  });
}

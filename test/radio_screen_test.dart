// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/models/radio.dart';
import 'package:ngskg_plus/models/song.dart';
import 'package:ngskg_plus/providers/player_provider.dart';
import 'package:ngskg_plus/screens/radio_screen.dart';
import 'package:ngskg_plus/services/music_service.dart';
import 'package:provider/provider.dart';

class _RadioService implements MusicService {
  final requests = <int, Completer<List<Song>>>{};

  @override
  Future<List<RadioStation>> getFmRecommend() async => const [
        RadioStation(id: 1, name: '舒缓频道'),
        RadioStation(id: 2, name: '活力频道'),
      ];

  @override
  Future<List<Song>> getFmSongs(int fmid) =>
      (requests[fmid] = Completer<List<Song>>()).future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Player extends ChangeNotifier implements PlayerProvider {
  @override
  Song? get currentSong => null;
  @override
  bool get isPlayerScreenVisible => false;
  @override
  bool get isMiniPlayerDismissed => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('快速切换电台时旧响应不会替换当前频道', (tester) async {
    final service = _RadioService();
    final player = _Player();
    addTearDown(player.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<PlayerProvider>.value(
      value: player,
      child: MaterialApp(home: RadioScreen(musicService: service)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('舒缓频道'));
    await tester.pump();
    await tester.tap(find.text('活力频道'));
    await tester.pump();
    service.requests[2]!.complete([
      const Song(id: 2, name: '新频道歌曲', artists: ['歌手']),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('新频道歌曲'), findsOneWidget);
    service.requests[1]!.complete([
      const Song(id: 1, name: '旧频道歌曲', artists: ['歌手']),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('新频道歌曲'), findsOneWidget);
    expect(find.text('旧频道歌曲'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

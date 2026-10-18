// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/models/playlist.dart';
import 'package:ngskg_plus/models/song.dart';
import 'package:ngskg_plus/models/theme_pack.dart';
import 'package:ngskg_plus/providers/player_provider.dart';
import 'package:ngskg_plus/providers/playlist_provider.dart';
import 'package:ngskg_plus/screens/playlist_detail_screen.dart';
import 'package:ngskg_plus/theme/app_theme.dart';
import 'package:ngskg_plus/ui/components/app_components.dart';
import 'package:ngskg_plus/ui/components/collection_header.dart';
import 'package:provider/provider.dart';

class _PlaylistState extends ChangeNotifier implements PlaylistProvider {
  final PlaylistDetail? detail;
  final bool loading;
  _PlaylistState(this.detail, {this.loading = false});
  @override
  PlaylistDetail? get currentPlaylist => detail;
  @override
  bool get isLoading => loading;
  @override
  List<Playlist> get userPlaylists => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PlayerState extends ChangeNotifier implements PlayerProvider {
  @override
  Song? get currentSong => null;
  @override
  bool get isPlayerScreenVisible => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final configuration in [(320.0, 2.0), (600.0, 3.0), (1024.0, 1.0)]) {
    testWidgets('详情封面头在 ${configuration.$1}px / ${configuration.$2} 倍字号下可阅读并操作',
        (tester) async {
      tester.view.physicalSize = Size(configuration.$1, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var played = false;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(ngsNagisa.lightScheme!, ngsNagisa),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(configuration.$2)),
          child: child!,
        ),
        home: Scaffold(
            body: AppPageBody(
                child: SingleChildScrollView(
          child: CollectionHeader(
            title: '这是一张拥有很长名称的专辑，也包含需要完整显示的歌手与作品信息',
            kind: '专辑',
            subtitle: '歌手名字也可以很长 · 128 首歌曲',
            actions: [
              FilledButton.icon(
                  onPressed: () => played = true,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('播放全部')),
              OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.favorite_border),
                  label: const Text('关注')),
            ],
          ),
        ))),
      ));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('播放全部'));
      await tester.tap(find.text('播放全部'));
      await tester.pump();
      expect(played, true);
      expect(tester.takeException(), isNull);
    });
  }

  for (final state in ['空歌单', '加载失败', '加载中']) {
    testWidgets('$state 始终保留可用返回入口', (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final playlists = _PlaylistState(
          state == '空歌单'
              ? const PlaylistDetail(
                  playlist: Playlist(id: 1, name: '空歌单'), songs: [])
              : null,
          loading: state == '加载中');
      final player = _PlayerState();
      addTearDown(playlists.dispose);
      addTearDown(player.dispose);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<PlaylistProvider>.value(value: playlists),
          ChangeNotifierProvider<PlayerProvider>.value(value: player),
        ],
        child: MaterialApp(
          theme: AppTheme.build(ngsNagisa.lightScheme!, ngsNagisa),
          home: Builder(
              builder: (context) => Scaffold(
                      body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const PlaylistDetailScreen())),
                    child: const Text('打开详情'),
                  ))),
        ),
      ));
      await tester.tap(find.text('打开详情'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(BackButton), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('打开详情'), findsOneWidget);
      expect(find.byType(PlaylistDetailScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

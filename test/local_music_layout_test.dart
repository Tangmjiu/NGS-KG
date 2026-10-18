// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/models/song.dart';
import 'package:ngskg_plus/navidrome/navidrome_login_screen.dart';
import 'package:ngskg_plus/navidrome/navidrome_models.dart';
import 'package:ngskg_plus/navidrome/navidrome_provider.dart';
import 'package:ngskg_plus/navidrome/navidrome_screen.dart';
import 'package:ngskg_plus/providers/local_music_provider.dart';
import 'package:ngskg_plus/providers/player_provider.dart';
import 'package:ngskg_plus/screens/local_music_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LocalMusic extends ChangeNotifier implements LocalMusicProvider {
  String query = '';
  final _songs = [
    Song(id: 1, name: '设备里的歌', artists: const ['歌手'], filePath: '/music/1.mp3'),
  ];

  @override
  List<Song> get songs =>
      _songs.where((song) => song.name.contains(query)).toList();
  @override
  bool get isScanning => false;
  @override
  bool get scanned => true;
  @override
  String get status => '找到 1 首';
  @override
  String? get highlightedFilePath => null;
  @override
  String get sortField => 'title';
  @override
  bool get sortAscending => true;
  @override
  void search(String value) {
    query = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Player extends ChangeNotifier implements PlayerProvider {
  @override
  Song? get currentSong => null;
  @override
  bool get isPlaying => false;
  @override
  bool get isPlayerScreenVisible => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Navidrome extends ChangeNotifier implements NavidromeProvider {
  BrowseLevel level = BrowseLevel.songs;
  int backCount = 0;
  int connectCount = 0;
  bool _connecting = false;
  final connection = Completer<bool>();
  String? failure;

  @override
  bool get connected => false;
  @override
  bool get connecting => _connecting;
  @override
  bool get isLoading => false;
  @override
  String? get error => failure;
  @override
  BrowseLevel get currentLevel => level;
  @override
  String? get selectedArtistName =>
      level == BrowseLevel.artists ? null : '名字非常长也应该可以完整浏览的测试歌手';
  @override
  String? get selectedAlbumName =>
      level == BrowseLevel.songs ? '名字非常长也应该可以完整浏览的测试专辑' : null;
  @override
  List<Song> get playbackSongs => [];
  @override
  List<SubsonicArtist> get artists => [];
  @override
  void goBack() {
    backCount++;
    level =
        level == BrowseLevel.songs ? BrowseLevel.albums : BrowseLevel.artists;
    notifyListeners();
  }

  @override
  Future<bool> connect(String url, String username, String password) async {
    connectCount++;
    _connecting = true;
    notifyListeners();
    final result = await connection.future;
    _connecting = false;
    failure = result ? null : '服务器暂时不可达';
    notifyListeners();
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _smallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _largeText(BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(1.25)),
      child: child!,
    );

void main() {
  testWidgets('窄屏本地搜索零结果仍能清空并恢复歌曲', (tester) async {
    _smallViewport(tester);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<LocalMusicProvider>(
            create: (_) => _LocalMusic()),
        ChangeNotifierProvider<PlayerProvider>(create: (_) => _Player()),
        ChangeNotifierProvider<NavidromeProvider>(create: (_) => _Navidrome()),
      ],
      child: MaterialApp(builder: _largeText, home: const LocalMusicScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('设备里的歌'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '不存在的歌曲');
    await tester.pumpAndSettle();
    expect(find.text('未找到本地歌曲'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.byTooltip('清空搜索'));
    await tester.pumpAndSettle();
    expect(find.text('设备里的歌'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏长面包屑不溢出，歌曲页可直接返回全部歌手', (tester) async {
    _smallViewport(tester);
    final navidrome = _Navidrome();
    await tester.pumpWidget(ChangeNotifierProvider<NavidromeProvider>.value(
      value: navidrome,
      child: MaterialApp(
        builder: _largeText,
        home: const Scaffold(body: SafeArea(child: NavidromeScreen())),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '全部歌手'));
    await tester.pumpAndSettle();
    expect(navidrome.backCount, 2);
    expect(navidrome.currentLevel, BrowseLevel.artists);
    expect(find.text('音乐库还没有歌手'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    navidrome.dispose();
  });

  testWidgets('连接过程中禁止重复提交，失败后恢复按钮并显示原因', (tester) async {
    _smallViewport(tester);
    SharedPreferences.setMockInitialValues({});
    final navidrome = _Navidrome();
    await tester.pumpWidget(ChangeNotifierProvider<NavidromeProvider>.value(
      value: navidrome,
      child:
          MaterialApp(builder: _largeText, home: const NavidromeLoginScreen()),
    ));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'https://music.example.com');
    await tester.enterText(fields.at(1), 'music');
    await tester.enterText(fields.at(2), 'password');
    await tester.ensureVisible(find.widgetWithText(FilledButton, '连接音乐库'));
    await tester.tap(find.widgetWithText(FilledButton, '连接音乐库'));
    await tester.pump();
    final connecting =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, '正在连接'));
    expect(connecting.onPressed, isNull);
    expect(navidrome.connectCount, 1);
    navidrome.connection.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('服务器暂时不可达'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '连接音乐库'))
            .onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    navidrome.dispose();
  });
}

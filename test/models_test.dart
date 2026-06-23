import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/models/song.dart';
import 'package:ngskg_plus/models/playlist.dart';
import 'package:ngskg_plus/models/user.dart';
import 'package:ngskg_plus/models/theme_pack.dart';

void main() {
  group('Song model', () {
    test('fromJson parses standard format', () {
      final json = {
        'id': 123,
        'name': 'Test Song',
        'artists': ['Artist A', 'Artist B'],
        'album': {'name': 'Test Album', 'picUrl': 'http://example.com/cover.jpg'},
        'duration': 300,
        'lyricUrl': 'http://example.com/lyric',
      };
      final song = Song.fromJson(json);
      expect(song.id, 123);
      expect(song.name, 'Test Song');
      expect(song.artists, ['Artist A', 'Artist B']);
      expect(song.artistDisplay, 'Artist A / Artist B');
      expect(song.albumName, 'Test Album');
      expect(song.albumCoverUrl, 'http://example.com/cover.jpg');
      expect(song.duration, 300);
      expect(song.isLocal, false);
    });

    test('fromKugouJson parses search result format', () {
      final json = {
        'Audioid': 456,
        'OriSongName': 'Search Song',
        'SongName': 'Search Song',
        'SingerName': 'Search Singer',
        'AlbumName': 'Album',
        'Image': 'http://example.com/{size}/cover.jpg',
        'Duration': 240,
        'FileHash': 'ABC123',
      };
      final song = Song.fromKugouJson(json);
      expect(song.id, 456);
      expect(song.name, 'Search Song');
      expect(song.artists, ['Search Singer']);
      expect(song.albumName, 'Album');
      expect(song.albumCoverUrl, 'http://example.com/480/cover.jpg');
      expect(song.duration, 240);
      expect(song.hash, 'ABC123');
    });

    test('fromTrackJson parses playlist track format', () {
      final json = {
        'audio_id': 789,
        'name': 'Artist Name - Track Title',
        'cover': 'http://example.com/{size}/cover.jpg',
        'timelen': 200123,
        'hash': 'HASH123',
        'audio_info': {'hash_320': 'HASH320', 'hash_flac': 'HASHFLAC'},
      };
      final song = Song.fromTrackJson(json);
      expect(song.id, 789);
      expect(song.name, 'Track Title');
      expect(song.artists, ['Artist Name']);
      expect(song.albumCoverUrl, 'http://example.com/480/cover.jpg');
      expect(song.duration, 200);
      expect(song.hash, 'HASH123');
      expect(song.qualities?['128'], 'HASH123');
      expect(song.qualities?['320'], 'HASH320');
      expect(song.qualities?['flac'], 'HASHFLAC');
    });

    test('fromTrackJson handles name without dash', () {
      final json = {
        'audio_id': 101,
        'name': 'Just a Name',
        'timelen': 180000,
      };
      final song = Song.fromTrackJson(json);
      expect(song.id, 101);
      expect(song.name, 'Just a Name');
      expect(song.artists, ['']);
    });

    test('fromRankJson parses rank song format', () {
      final json = {
        'audio_id': 202,
        'songname': 'Rank Artist - Rank Song',
        'author_name': 'Rank Artist',
        'audio_info': {
          'hash_128': 'H128',
          'hash_320': 'H320',
          'duration_128': 180,
        },
        'trans_param': {'union_cover': 'http://example.com/{size}/cover.jpg'},
      };
      final song = Song.fromRankJson(json);
      expect(song.id, 202);
      expect(song.name, 'Rank Song');
      expect(song.artists, ['Rank Artist']);
      expect(song.albumCoverUrl, 'http://example.com/480/cover.jpg');
      expect(song.duration, 0); // 180ms / 1000 = 0 seconds
      expect(song.hash, 'H128');
      expect(song.qualities?['128'], 'H128');
      expect(song.qualities?['320'], 'H320');
    });

    test('isLocal returns true when filePath is set', () {
      final online = Song(id: 1, name: 'Test', artists: []);
      expect(online.isLocal, false);

      final local = Song(id: 1, name: 'Test', artists: [], filePath: '/path/to/file.mp3');
      expect(local.isLocal, true);

      final cloud = Song(id: 1, name: 'Test', artists: [], filePath: 'http://example.com/song.mp3');
      expect(cloud.isLocal, true);
    });

    test('qualityKeys order', () {
      expect(Song.qualityKeys, ['128', '320', 'flac', 'high', 'super']);
      expect(Song.qualityLabels, ['标准', 'HQ', 'SQ', 'Hi-Res', '无损']);
    });
  });

  group('SongUrl model', () {
    test('fromJson extracts first URL from array', () {
      final json = {
        'url': ['http://example.com/1.mp3', 'http://example.com/2.mp3'],
        'extName': 'mp3',
      };
      final url = SongUrl.fromJson(json);
      expect(url.url, 'http://example.com/1.mp3');
    });

    test('fromJson handles single URL string', () {
      final json = {'url': 'http://example.com/song.mp3', 'extName': 'mp3'};
      final url = SongUrl.fromJson(json);
      expect(url.url, 'http://example.com/song.mp3');
    });

    test('fromJson handles empty URLs', () {
      final json = {'url': <String>[], 'extName': 'mp3'};
      final url = SongUrl.fromJson(json);
      expect(url.url, '');
    });
  });

  group('Playlist model', () {
    test('fromJson parses standard format', () {
      final json = {
        'specialid': 100,
        'specialname': 'My Playlist',
        'imgurl': 'http://example.com/{size}/cover.jpg',
        'intro': 'A great playlist',
        'songcount': 50,
        'global_collection_id': 'collection_3_100_1_0',
        'list_create_userid': 42,
      };
      final pl = Playlist.fromJson(json);
      expect(pl.id, 100);
      expect(pl.name, 'My Playlist');
      expect(pl.coverUrl, 'http://example.com/480/cover.jpg');
      expect(pl.description, 'A great playlist');
      expect(pl.trackCount, 50);
      expect(pl.globalCollectionId, 'collection_3_100_1_0');
      expect(pl.createUserId, 42);
    });

    test('fromJson handles user playlist fields', () {
      final json = {
        'name': 'User Playlist',
        'pic': 'http://example.com/{size}/pic.jpg',
        'count': 30,
        'global_collection_id': 'collection_3_200_2_0',
      };
      final pl = Playlist.fromJson(json);
      expect(pl.id, 0);
      expect(pl.name, 'User Playlist');
      expect(pl.coverUrl, 'http://example.com/480/pic.jpg');
      expect(pl.trackCount, 30);
    });

    test('fromJson returns defaults for null fields', () {
      final pl = Playlist.fromJson({});
      expect(pl.id, 0);
      expect(pl.name, '');
      expect(pl.coverUrl, null);
      expect(pl.trackCount, 0);
    });
  });

  group('PlaylistDetail model', () {
    test('fromKugouJson parses playlist detail with songs', () {
      final json = {
        'specialname': 'Detail Playlist',
        'songs': [
          {'audio_id': 1, 'name': 'A - Song1', 'timelen': 200000},
          {'audio_id': 2, 'name': 'B - Song2', 'timelen': 180000},
        ],
      };
      final detail = PlaylistDetail.fromKugouJson(json);
      expect(detail.playlist.name, 'Detail Playlist');
      expect(detail.songs.length, 2);
      expect(detail.songs[0].name, 'Song1');
      expect(detail.songs[1].name, 'Song2');
    });
  });

  group('User model', () {
    test('fromJson parses standard fields', () {
      final json = {
        'userId': 1001,
        'nickname': 'TestUser',
        'avatarUrl': 'http://example.com/avatar.jpg',
        'token': 'abcdef123',
      };
      final user = User.fromJson(json);
      expect(user.userId, 1001);
      expect(user.nickname, 'TestUser');
      expect(user.avatarUrl, 'http://example.com/avatar.jpg');
      expect(user.token, 'abcdef123');
      expect(user.isVipActive, false);
    });

    test('fromJson parses KuGou API fields', () {
      final json = {
        'userid': 1002,
        'nickname': 'KuGouUser',
        'pic': 'http://example.com/pic.jpg',
        'token': 'xyz789',
        'is_vip': 1,
        'vip_type': 6,
      };
      final user = User.fromJson(json);
      expect(user.userId, 1002);
      expect(user.nickname, 'KuGouUser');
      expect(user.avatarUrl, 'http://example.com/pic.jpg');
      expect(user.isVipActive, true);
      expect(user.vipType, 6);
      expect(user.vipLevelDisplay, '豪华VIP');
    });

    test('vipLevelDisplay returns correct strings', () {
      final normal = User(isVip: 0);
      expect(normal.vipLevelDisplay, '普通用户');

      final musicPack = User(isVip: 1, vipType: 1);
      expect(musicPack.vipLevelDisplay, '付费音乐包');

      final deluxe = User(isVip: 1, vipType: 6);
      expect(deluxe.vipLevelDisplay, '豪华VIP');
    });

    test('toJson serializes correctly', () {
      final user = User(userId: 1001, nickname: 'Test', avatarUrl: 'http://a.jpg', token: 'tok');
      final json = user.toJson();
      expect(json['userId'], 1001);
      expect(json['nickname'], 'Test');
      expect(json['avatarUrl'], 'http://a.jpg');
      expect(json['token'], 'tok');
    });
  });

  group('ThemePack serialization', () {
    test('ngsNagisa toJson/fromJson round-trip preserves identity', () {
      // Convert built-in theme to JSON and back
      final json = ngsNagisa.toJson();
      final restored = ThemePack.fromJson(json);

      expect(restored.id, ngsNagisa.id);
      expect(restored.name, ngsNagisa.name);
      expect(restored.author, ngsNagisa.author);
      expect(restored.version, ngsNagisa.version);
      expect(restored.isBuiltIn, ngsNagisa.isBuiltIn);
      expect(restored.description, ngsNagisa.description);
      expect(restored.assetFiles?.length, ngsNagisa.assetFiles?.length);
      expect(restored.fontWeightFiles, isNull);
    });

    test('ColorScheme round-trip preserves all 30 light colors', () {
      final scheme = ngsNagisa.lightScheme;
      expect(scheme, isNotNull);

      final serialized = _serializeColorSchemeForTest(scheme!);
      final parsed = _parseColorSchemeForTest(serialized, Brightness.light);

      expect(parsed.primary.value, scheme.primary.value);
      expect(parsed.onPrimary.value, scheme.onPrimary.value);
      expect(parsed.primaryContainer.value, scheme.primaryContainer.value);
      expect(parsed.onPrimaryContainer.value, scheme.onPrimaryContainer.value);
      expect(parsed.secondary.value, scheme.secondary.value);
      expect(parsed.onSecondary.value, scheme.onSecondary.value);
      expect(parsed.secondaryContainer.value, scheme.secondaryContainer.value);
      expect(parsed.onSecondaryContainer.value, scheme.onSecondaryContainer.value);
      expect(parsed.tertiary.value, scheme.tertiary.value);
      expect(parsed.onTertiary.value, scheme.onTertiary.value);
      expect(parsed.tertiaryContainer.value, scheme.tertiaryContainer.value);
      expect(parsed.onTertiaryContainer.value, scheme.onTertiaryContainer.value);
      expect(parsed.error.value, scheme.error.value);
      expect(parsed.onError.value, scheme.onError.value);
      expect(parsed.errorContainer.value, scheme.errorContainer.value);
      expect(parsed.onErrorContainer.value, scheme.onErrorContainer.value);
      expect(parsed.surface.value, scheme.surface.value);
      expect(parsed.surfaceDim.value, scheme.surfaceDim.value);
      expect(parsed.surfaceBright.value, scheme.surfaceBright.value);
      expect(parsed.surfaceContainerLowest.value, scheme.surfaceContainerLowest.value);
      expect(parsed.surfaceContainerLow.value, scheme.surfaceContainerLow.value);
      expect(parsed.surfaceContainer.value, scheme.surfaceContainer.value);
      expect(parsed.surfaceContainerHigh.value, scheme.surfaceContainerHigh.value);
      expect(parsed.surfaceContainerHighest.value, scheme.surfaceContainerHighest.value);
      expect(parsed.onSurface.value, scheme.onSurface.value);
      expect(parsed.onSurfaceVariant.value, scheme.onSurfaceVariant.value);
      expect(parsed.outline.value, scheme.outline.value);
      expect(parsed.outlineVariant.value, scheme.outlineVariant.value);
      expect(parsed.inverseSurface.value, scheme.inverseSurface.value);
      expect(parsed.inversePrimary.value, scheme.inversePrimary.value);
    });

    test('ColorScheme round-trip preserves all 30 dark colors', () {
      final scheme = ngsNagisa.darkScheme;
      expect(scheme, isNotNull);

      final serialized = _serializeColorSchemeForTest(scheme!);
      final parsed = _parseColorSchemeForTest(serialized, Brightness.dark);

      expect(parsed.primary.value, scheme.primary.value);
      expect(parsed.onPrimary.value, scheme.onPrimary.value);
      expect(parsed.primaryContainer.value, scheme.primaryContainer.value);
      expect(parsed.onPrimaryContainer.value, scheme.onPrimaryContainer.value);
      expect(parsed.secondary.value, scheme.secondary.value);
      expect(parsed.onSecondary.value, scheme.onSecondary.value);
      expect(parsed.secondaryContainer.value, scheme.secondaryContainer.value);
      expect(parsed.onSecondaryContainer.value, scheme.onSecondaryContainer.value);
      expect(parsed.tertiary.value, scheme.tertiary.value);
      expect(parsed.onTertiary.value, scheme.onTertiary.value);
      expect(parsed.tertiaryContainer.value, scheme.tertiaryContainer.value);
      expect(parsed.onTertiaryContainer.value, scheme.onTertiaryContainer.value);
      expect(parsed.error.value, scheme.error.value);
      expect(parsed.onError.value, scheme.onError.value);
      expect(parsed.errorContainer.value, scheme.errorContainer.value);
      expect(parsed.onErrorContainer.value, scheme.onErrorContainer.value);
      expect(parsed.surface.value, scheme.surface.value);
      expect(parsed.surfaceDim.value, scheme.surfaceDim.value);
      expect(parsed.surfaceBright.value, scheme.surfaceBright.value);
      expect(parsed.surfaceContainerLowest.value, scheme.surfaceContainerLowest.value);
      expect(parsed.surfaceContainerLow.value, scheme.surfaceContainerLow.value);
      expect(parsed.surfaceContainer.value, scheme.surfaceContainer.value);
      expect(parsed.surfaceContainerHigh.value, scheme.surfaceContainerHigh.value);
      expect(parsed.surfaceContainerHighest.value, scheme.surfaceContainerHighest.value);
      expect(parsed.onSurface.value, scheme.onSurface.value);
      expect(parsed.onSurfaceVariant.value, scheme.onSurfaceVariant.value);
      expect(parsed.outline.value, scheme.outline.value);
      expect(parsed.outlineVariant.value, scheme.outlineVariant.value);
      expect(parsed.inverseSurface.value, scheme.inverseSurface.value);
      expect(parsed.inversePrimary.value, scheme.inversePrimary.value);
    });

    test('FontWeightFiles serialization round-trip', () {
      final files = FontWeightFiles(
        regular: '/path/to/regular.ttf',
        medium: '/path/to/medium.ttf',
        bold: '/path/to/bold.ttf',
      );
      final json = files.toJson();
      final restored = FontWeightFiles.fromJson(json);

      expect(restored.regular, files.regular);
      expect(restored.medium, files.medium);
      expect(restored.bold, files.bold);
    });

    test('md3Default with null color schemes round-trips correctly', () {
      // md3Default has null lightScheme/darkScheme
      final json = md3Default.toJson();
      final restored = ThemePack.fromJson(json);

      expect(restored.id, md3Default.id);
      expect(restored.name, md3Default.name);
      expect(restored.lightScheme, isNull);
      expect(restored.darkScheme, isNull);
      expect(restored.assetFiles, isNull);
    });

    test('full custom ThemePack round-trip preserves all fields', () {
      const custom = ThemePack(
        id: 'test_custom',
        name: 'Test Custom',
        author: 'Tester',
        version: 2,
        description: 'A test pack',
        isBuiltIn: false,
        previewPath: '/tmp/preview.png',
        fontFamily: 'TestFont',
        fontWeightFiles: FontWeightFiles(
          regular: '/tmp/regular.ttf',
          medium: '/tmp/medium.ttf',
        ),
        playerBgPath: '/tmp/bg.png',
        assetFiles: {'icon': '/tmp/icon.png', 'loading': '/tmp/loading.png'},
        lightScheme: ColorScheme.light(primary: Color(0xFFFF0000)),
        darkScheme: ColorScheme.dark(primary: Color(0xFF00FF00)),
        shapes: {'sm': 12, 'md': 16, 'lg': 24},
        motion: ThemeMotion(durationScale: 0.8, curve: 'linear'),
        components: ThemeComponents(
          navigationBarElevation: 2,
          cardElevation: 4,
          dialogElevation: 8,
        ),
      );

      final json = custom.toJson();
      final restored = ThemePack.fromJson(json);

      expect(restored.id, custom.id);
      expect(restored.name, custom.name);
      expect(restored.author, custom.author);
      expect(restored.version, custom.version);
      expect(restored.description, custom.description);
      expect(restored.isBuiltIn, custom.isBuiltIn);
      expect(restored.previewPath, custom.previewPath);
      expect(restored.fontFamily, custom.fontFamily);
      expect(restored.playerBgPath, custom.playerBgPath);
      expect(restored.assetFiles?['icon'], '${custom.assetFiles!['icon']}');
      expect(restored.assetFiles?['loading'], '${custom.assetFiles!['loading']}');
      expect(restored.fontWeightFiles?.regular, custom.fontWeightFiles?.regular);
      expect(restored.fontWeightFiles?.medium, custom.fontWeightFiles?.medium);
      expect(restored.fontWeightFiles?.bold, custom.fontWeightFiles?.bold);
      expect(restored.shapes?['sm'], custom.shapes?['sm']);
      expect(restored.shapes?['md'], custom.shapes?['md']);
      expect(restored.shapes?['lg'], custom.shapes?['lg']);
      expect(restored.motion.durationScale, custom.motion.durationScale);
      expect(restored.motion.curve, custom.motion.curve);
      expect(restored.components.navigationBarElevation, custom.components.navigationBarElevation);
      expect(restored.components.cardElevation, custom.components.cardElevation);
      expect(restored.components.dialogElevation, custom.components.dialogElevation);
      expect(restored.lightScheme?.primary.value, custom.lightScheme?.primary.value);
      expect(restored.darkScheme?.primary.value, custom.darkScheme?.primary.value);
    });
  });
}

// ── Test helpers (mirror the private helpers in theme_pack.dart) ──

Map<String, String> _serializeColorSchemeForTest(ColorScheme s) {
  String colorHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  return {
    'primary': colorHex(s.primary),
    'onPrimary': colorHex(s.onPrimary),
    'primaryContainer': colorHex(s.primaryContainer),
    'onPrimaryContainer': colorHex(s.onPrimaryContainer),
    'secondary': colorHex(s.secondary),
    'onSecondary': colorHex(s.onSecondary),
    'secondaryContainer': colorHex(s.secondaryContainer),
    'onSecondaryContainer': colorHex(s.onSecondaryContainer),
    'tertiary': colorHex(s.tertiary),
    'onTertiary': colorHex(s.onTertiary),
    'tertiaryContainer': colorHex(s.tertiaryContainer),
    'onTertiaryContainer': colorHex(s.onTertiaryContainer),
    'error': colorHex(s.error),
    'onError': colorHex(s.onError),
    'errorContainer': colorHex(s.errorContainer),
    'onErrorContainer': colorHex(s.onErrorContainer),
    'surface': colorHex(s.surface),
    'surfaceDim': colorHex(s.surfaceDim),
    'surfaceBright': colorHex(s.surfaceBright),
    'surfaceContainerLowest': colorHex(s.surfaceContainerLowest),
    'surfaceContainerLow': colorHex(s.surfaceContainerLow),
    'surfaceContainer': colorHex(s.surfaceContainer),
    'surfaceContainerHigh': colorHex(s.surfaceContainerHigh),
    'surfaceContainerHighest': colorHex(s.surfaceContainerHighest),
    'onSurface': colorHex(s.onSurface),
    'onSurfaceVariant': colorHex(s.onSurfaceVariant),
    'outline': colorHex(s.outline),
    'outlineVariant': colorHex(s.outlineVariant),
    'inverseSurface': colorHex(s.inverseSurface),
    'inversePrimary': colorHex(s.inversePrimary),
  };
}

ColorScheme _parseColorSchemeForTest(Map<String, dynamic> data, Brightness brightness) {
  Color c(String key, Color fallback) {
    final v = data[key] as String?;
    if (v == null || v.isEmpty) return fallback;
    final h = v.replaceFirst('#', '');
    final val = int.tryParse(h, radix: 16);
    if (val == null) return fallback;
    return Color(0xFF000000 | val);
  }

  if (brightness == Brightness.light) {
    return ColorScheme.light(
      primary: c('primary', const Color(0xFF2CA1F4)),
      onPrimary: c('onPrimary', const Color(0xFFFFFFFF)),
      primaryContainer: c('primaryContainer', const Color(0xFFD2E5FF)),
      onPrimaryContainer: c('onPrimaryContainer', const Color(0xFF001D35)),
      secondary: c('secondary', const Color(0xFF565F71)),
      onSecondary: c('onSecondary', const Color(0xFFFFFFFF)),
      secondaryContainer: c('secondaryContainer', const Color(0xFFDAE2F9)),
      onSecondaryContainer: c('onSecondaryContainer', const Color(0xFF131C2B)),
      tertiary: c('tertiary', const Color(0xFF6E5676)),
      onTertiary: c('onTertiary', const Color(0xFFFFFFFF)),
      tertiaryContainer: c('tertiaryContainer', const Color(0xFFF8D8FE)),
      onTertiaryContainer: c('onTertiaryContainer', const Color(0xFF271430)),
      error: c('error', const Color(0xFFBA1A1A)),
      onError: c('onError', const Color(0xFFFFFFFF)),
      errorContainer: c('errorContainer', const Color(0xFFFFDAD6)),
      onErrorContainer: c('onErrorContainer', const Color(0xFF410002)),
      surface: c('surface', const Color(0xFFFDF8FF)),
      surfaceDim: c('surfaceDim', const Color(0xFFDED8E1)),
      surfaceBright: c('surfaceBright', const Color(0xFFFDF8FF)),
      surfaceContainerLowest: c('surfaceContainerLowest', const Color(0xFFFFFFFF)),
      surfaceContainerLow: c('surfaceContainerLow', const Color(0xFFF7F2FB)),
      surfaceContainer: c('surfaceContainer', const Color(0xFFF2ECF5)),
      surfaceContainerHigh: c('surfaceContainerHigh', const Color(0xFFEBE6EF)),
      surfaceContainerHighest: c('surfaceContainerHighest', const Color(0xFFE0DAE3)),
      onSurface: c('onSurface', const Color(0xFF1C1B1F)),
      onSurfaceVariant: c('onSurfaceVariant', const Color(0xFF49454F)),
      outline: c('outline', const Color(0xFF7A7580)),
      outlineVariant: c('outlineVariant', const Color(0xFFCAC4CD)),
      inverseSurface: c('inverseSurface', const Color(0xFF313033)),
      inversePrimary: c('inversePrimary', const Color(0xFFA9D0FF)),
    );
  } else {
    return ColorScheme.dark(
      primary: c('primary', const Color(0xFFAAC7FF)),
      onPrimary: c('onPrimary', const Color(0xFF003258)),
      primaryContainer: c('primaryContainer', const Color(0xFF00497D)),
      onPrimaryContainer: c('onPrimaryContainer', const Color(0xFFD2E5FF)),
      secondary: c('secondary', const Color(0xFFBEC6DC)),
      onSecondary: c('onSecondary', const Color(0xFF283141)),
      secondaryContainer: c('secondaryContainer', const Color(0xFF3E4759)),
      onSecondaryContainer: c('onSecondaryContainer', const Color(0xFFDAE2F9)),
      tertiary: c('tertiary', const Color(0xFFDBBDE2)),
      onTertiary: c('onTertiary', const Color(0xFF3D2846)),
      tertiaryContainer: c('tertiaryContainer', const Color(0xFF553F5D)),
      onTertiaryContainer: c('onTertiaryContainer', const Color(0xFFF8D8FE)),
      error: c('error', const Color(0xFFFFB4AB)),
      onError: c('onError', const Color(0xFF690005)),
      errorContainer: c('errorContainer', const Color(0xFF93000A)),
      onErrorContainer: c('onErrorContainer', const Color(0xFFFFDAD6)),
      surface: c('surface', const Color(0xFF141318)),
      surfaceDim: c('surfaceDim', const Color(0xFF141318)),
      surfaceBright: c('surfaceBright', const Color(0xFF3A383E)),
      surfaceContainerLowest: c('surfaceContainerLowest', const Color(0xFF0E0E13)),
      surfaceContainerLow: c('surfaceContainerLow', const Color(0xFF1C1B20)),
      surfaceContainer: c('surfaceContainer', const Color(0xFF201F24)),
      surfaceContainerHigh: c('surfaceContainerHigh', const Color(0xFF2B292F)),
      surfaceContainerHighest: c('surfaceContainerHighest', const Color(0xFF36343A)),
      onSurface: c('onSurface', const Color(0xFFE6E1E6)),
      onSurfaceVariant: c('onSurfaceVariant', const Color(0xFFCAC4CD)),
      outline: c('outline', const Color(0xFF948F99)),
      outlineVariant: c('outlineVariant', const Color(0xFF49454F)),
      inverseSurface: c('inverseSurface', const Color(0xFFE6E1E6)),
      inversePrimary: c('inversePrimary', const Color(0xFF00619F)),
    );
  }
}

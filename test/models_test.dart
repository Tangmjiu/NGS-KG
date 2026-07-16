import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/models/song.dart';
import 'package:ngskg_plus/models/playlist.dart';
import 'package:ngskg_plus/models/user.dart';

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
      expect(Song.qualityKeys, ['128', '320', 'flac', 'high']);
      expect(Song.qualityLabels, ['标准', 'HQ', 'SQ', 'Hi-Res']);
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
}

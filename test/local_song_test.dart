import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/models/local_song.dart';

void main() {
  group('LocalSong.displayName', () {
    test('strips .mp3 extension from title', () {
      const song = LocalSong(title: 'song.mp3', filePath: '/path/song.mp3');
      expect(song.displayName, 'song');
    });

    test('strips .flac extension', () {
      const song = LocalSong(title: 'track.flac', filePath: '/path/track.flac');
      expect(song.displayName, 'track');
    });

    test('strips .wav extension', () {
      const song = LocalSong(title: 'recording.wav', filePath: '/path/recording.wav');
      expect(song.displayName, 'recording');
    });

    test('strips .aac extension', () {
      const song = LocalSong(title: 'audio.aac', filePath: '/path/audio.aac');
      expect(song.displayName, 'audio');
    });

    test('strips .ogg extension', () {
      const song = LocalSong(title: 'music.ogg', filePath: '/path/music.ogg');
      expect(song.displayName, 'music');
    });

    test('strips .wma extension', () {
      const song = LocalSong(title: 'old_song.wma', filePath: '/path/old.wma');
      expect(song.displayName, 'old_song');
    });

    test('strips .m4a extension', () {
      const song = LocalSong(title: 'alac.m4a', filePath: '/path/alac.m4a');
      expect(song.displayName, 'alac');
    });

    test('strips .opus extension', () {
      const song = LocalSong(title: 'voice.opus', filePath: '/path/voice.opus');
      expect(song.displayName, 'voice');
    });

    test('returns title unchanged when no known extension', () {
      const song = LocalSong(title: 'My Song Title', filePath: '/path/song.mp3');
      expect(song.displayName, 'My Song Title');
    });

    test('handles title with dots not at end', () {
      const song = LocalSong(title: 'song.v2.flac', filePath: '/path/song.flac');
      expect(song.displayName, 'song.v2');
    });

    test('returns empty string for empty title', () {
      const song = LocalSong(title: '', filePath: '/path/song.mp3');
      expect(song.displayName, '');
    });
  });

  group('LocalSong construction', () {
    test('default values are zero/empty', () {
      const song = LocalSong(title: 'test', filePath: '/path/test.mp3');
      expect(song.artist, isNull);
      expect(song.album, isNull);
      expect(song.mediaStoreId, isNull);
      expect(song.duration, 0);
      expect(song.size, 0);
      expect(song.bitrate, isNull);
      expect(song.sampleRate, isNull);
      expect(song.codec, isNull);
      expect(song.lyrics, isNull);
      expect(song.albumCoverPath, isNull);
    });

    test('stores all provided values', () {
      const song = LocalSong(
        title: 'Test Song',
        artist: 'Test Artist',
        album: 'Test Album',
        filePath: '/music/test.flac',
        mediaStoreId: 12345,
        duration: 300,
        size: 1024000,
        bitrate: 900,
        sampleRate: 44100,
        codec: 'FLAC',
        lyrics: '[00:00]Test',
        albumCoverPath: '/cache/cover.jpg',
      );
      expect(song.title, 'Test Song');
      expect(song.artist, 'Test Artist');
      expect(song.album, 'Test Album');
      expect(song.filePath, '/music/test.flac');
      expect(song.mediaStoreId, 12345);
      expect(song.duration, 300);
      expect(song.size, 1024000);
      expect(song.bitrate, 900);
      expect(song.sampleRate, 44100);
      expect(song.codec, 'FLAC');
      expect(song.lyrics, '[00:00]Test');
      expect(song.albumCoverPath, '/cache/cover.jpg');
    });
  });
}

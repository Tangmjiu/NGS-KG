// Copyright (c) 2025-2026 mjiutang
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/models/song.dart';
import 'package:ngskg_plus/providers/playlist_queue.dart';

Song _song(int id) => Song(id: id, name: '$id', artists: const []);

void main() {
  test('队列复制来源列表，并只在结构变化后生成新的只读快照', () {
    final source = [_song(1), _song(2), _song(3)];
    final queue = PlaylistQueue()..setPlaylist(source);
    addTearDown(queue.dispose);
    final snapshot = queue.playlist;
    expect(identical(snapshot, queue.playlist), isTrue);
    expect(() => snapshot.clear(), throwsUnsupportedError);

    queue.move(0, 2);
    expect(source.map((s) => s.id), [1, 2, 3]);
    expect(snapshot.map((s) => s.id), [1, 2, 3]);
    expect(queue.playlist.map((s) => s.id), [2, 3, 1]);
    final reordered = queue.playlist;
    queue.playIndex(0);
    expect(identical(reordered, queue.playlist), isTrue);

    source.clear();
    expect(queue.playlist, hasLength(3));
    queue.removeAt(0);
    queue.append([_song(4)]);
    expect(reordered.map((s) => s.id), [2, 3, 1]);
  });

  test('空队列、越界起始索引与最后一首删除后保持有效索引', () {
    final queue = PlaylistQueue();
    addTearDown(queue.dispose);
    queue.setPlaylist([], startIndex: -3);
    expect(queue.currentSong, isNull);
    queue.insertAt(0, _song(1));
    expect(queue.currentSong?.id, 1);
    queue.setPlaylist([_song(2), _song(3)], startIndex: 99);
    expect(queue.currentIndex, 1);
    queue.removeAt(1);
    queue.removeAt(0);
    expect(queue.currentSong, isNull);
    queue.append([_song(4)]);
    expect(queue.currentSong?.id, 4);
    queue.setPlaylist([_song(5)], startIndex: -1);
    expect(queue.currentIndex, 0);
  });

  test('随机模式插入下一首不会使新歌曲永远缺席随机顺序', () {
    final queue = PlaylistQueue()
      ..setPlaylist([_song(1), _song(2), _song(3)])
      ..setPlayMode(PlayMode.shuffle);
    addTearDown(queue.dispose);
    queue.insertAt(1, _song(4));
    final next = queue.nextIndex()!;
    expect(queue.playlist[next].id, 4);
  });

  test('随机游标前删除歌曲后，previous 仍指向实际上一首', () {
    final queue = PlaylistQueue()
      ..setPlaylist(List.generate(4, _song))
      ..setPlayMode(PlayMode.shuffle);
    addTearDown(queue.dispose);
    final first = queue.currentSong!;
    queue.playIndex(queue.nextIndex()!);
    final second = queue.currentSong!;
    queue.playIndex(queue.nextIndex()!);
    final current = queue.currentSong!;

    queue.removeAt(queue.playlist.indexOf(first));
    expect(queue.currentSong, same(current));
    final previous = queue.previousIndex()!;
    expect(queue.playlist[previous], same(second));
  });

  test('替换随机队列与空队列追加歌曲后恢复随机遍历', () {
    final queue = PlaylistQueue()..setPlayMode(PlayMode.shuffle);
    addTearDown(queue.dispose);
    queue.append([_song(1), _song(2)]);
    expect(queue.hasNext(), isTrue);
    expect(queue.nextIndex(), isNotNull);
    queue.setPlaylist([_song(3), _song(4)], startIndex: 1);
    expect(queue.hasNext(), isTrue);
    expect(queue.nextIndex(), 0);
  });
}

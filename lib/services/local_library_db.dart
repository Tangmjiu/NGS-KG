import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';
import '../models/song.dart';
import '../utils/logger.dart';

/// 本地音乐库 SQLite 持久化。
///
/// 扫描结果写入 DB，App 重启后从缓存快速加载，
/// 无需每次全量扫描 MediaStore。
class LocalLibraryDB {
  static const _dbName = 'local_library.db';
  static const _tableSongs = 'local_songs';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableSongs (
            filePath TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT,
            album TEXT,
            albumCoverPath TEXT,
            duration INTEGER DEFAULT 0,
            size INTEGER DEFAULT 0,
            bitrate INTEGER,
            codec TEXT,
            lyrics TEXT,
            mediaStoreId INTEGER,
            scannedAt INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  /// 批量写入扫描结果（REPLACE 模式，主键冲突则覆盖）。
  Future<void> saveSongs(List<Song> songs) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final s in songs) {
      if (s.filePath == null) continue;
      batch.insert(
        _tableSongs,
        _songToRow(s, now),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// 加载所有缓存的本地歌曲。
  Future<List<Song>> loadAll() async {
    final db = await _database;
    final rows =
        await db.query(_tableSongs, orderBy: 'title COLLATE NOCASE ASC');
    return rows.map(_rowToSong).toList();
  }

  /// 获取所有已缓存的文件路径集合（用于增量 diff）。
  Future<Set<String>> getCachedPaths() async {
    final db = await _database;
    final rows = await db.query(_tableSongs, columns: ['filePath']);
    return rows.map((r) => r['filePath'] as String).toSet();
  }

  /// 删除不再存在的歌曲。
  Future<void> removeByPaths(List<String> paths) async {
    if (paths.isEmpty) return;
    final db = await _database;
    final placeholders = paths.map((_) => '?').join(',');
    await db.delete(
      _tableSongs,
      where: 'filePath IN ($placeholders)',
      whereArgs: paths,
    );
  }

  /// 清空所有缓存。
  Future<void> clear() async {
    final db = await _database;
    await db.delete(_tableSongs);
  }

  /// 获取缓存中的歌曲数量。
  Future<int> get count async {
    final db = await _database;
    final result =
        await db.rawQuery('SELECT COUNT(*) AS cnt FROM $_tableSongs');
    return (result.first['cnt'] as int?) ?? 0;
  }

  // ── 序列化 ──

  static Map<String, dynamic> _songToRow(Song s, int scannedAt) {
    // 提取原始封面路径（去掉 file:// 前缀）
    String? coverPath = s.albumCoverUrl;
    if (coverPath != null && coverPath.startsWith('file:')) {
      coverPath = Uri.parse(coverPath).toFilePath();
    }
    return {
      'filePath': s.filePath,
      'title': s.name,
      'artist': s.artists.isNotEmpty ? s.artists.first : null,
      'album': s.albumName,
      'albumCoverPath': coverPath,
      'duration': s.duration,
      'size': s.size,
      'bitrate': s.bitrate,
      'codec': s.codec,
      'lyrics': s.lyrics,
      'mediaStoreId': s.mediaStoreId,
      'scannedAt': scannedAt,
    };
  }

  static Song _rowToSong(Map<String, dynamic> row) {
    return Song.fromLocal(
      title: row['title'] as String,
      artist: row['artist'] as String?,
      album: row['album'] as String?,
      filePath: row['filePath'] as String,
      mediaStoreId: row['mediaStoreId'] as int?,
      duration: (row['duration'] as int?) ?? 0,
      size: (row['size'] as int?) ?? 0,
      bitrate: row['bitrate'] as int?,
      codec: row['codec'] as String?,
      lyrics: row['lyrics'] as String?,
      albumCoverPath: row['albumCoverPath'] as String?,
    );
  }
}

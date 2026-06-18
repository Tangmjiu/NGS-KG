import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class CacheService {
  static final CacheService _instance = CacheService._();
  static CacheService get instance => _instance;
  CacheService._();

  static const int _maxCacheCount = 500;

  Database? _db;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    _db = await openDatabase(
      path.join(dir.path, 'cache.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cache (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            expires_at INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_expires ON cache(expires_at)');
      },
    );
    _initialized = true;
    _cleanExpired();
  }

  Future<void> put(String key, String value, {Duration ttl = const Duration(hours: 2)}) async {
    if (_db == null) return;
    await _enforceCapacity();
    final expiresAt = DateTime.now().millisecondsSinceEpoch + ttl.inMilliseconds;
    await _db!.insert('cache', {
      'key': key,
      'value': value,
      'expires_at': expiresAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _enforceCapacity() async {
    if (_db == null) return;
    final count = (await _db!.rawQuery('SELECT COUNT(*) as cnt FROM cache'))
            .firstOrNull?['cnt'] as int? ?? 0;
    if (count >= _maxCacheCount) {
      await _db!.rawDelete('''
        DELETE FROM cache WHERE key IN (
          SELECT key FROM cache ORDER BY expires_at ASC LIMIT ?
        )
      ''', [(count - _maxCacheCount + 100)]);
    }
  }

  Future<String?> get(String key) async {
    if (_db == null) return null;
    final rows = await _db!.query('cache',
        where: 'key = ? AND expires_at > ?',
        whereArgs: [key, DateTime.now().millisecondsSinceEpoch]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> remove(String key) async {
    if (_db == null) return;
    await _db!.delete('cache', where: 'key = ?', whereArgs: [key]);
  }

  Future<void> clear() async {
    if (_db == null) return;
    await _db!.delete('cache');
  }

  Future<void> _cleanExpired() async {
    if (_db == null) return;
    await _db!.delete('cache', where: 'expires_at < ?',
        whereArgs: [DateTime.now().millisecondsSinceEpoch]);
  }

  // Convenience methods with JSON serialization
  Future<void> putJson(String key, dynamic value, {Duration? ttl}) async {
    await put(key, jsonEncode(value), ttl: ttl ?? const Duration(hours: 2));
  }

  Future<dynamic> getJson(String key) async {
    final str = await get(key);
    if (str == null) return null;
    return jsonDecode(str);
  }
}

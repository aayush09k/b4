import 'dart:convert';
import 'package:sqlite3/sqlite3.dart';

class B4CacheManager {
  final Database _database;
  final int maxCacheSize;
  final Map<String, Map<String, dynamic>> _cache = {};

  B4CacheManager(this._database, {this.maxCacheSize = 10}) {
    _initializeCacheTable();
    _loadCacheFromDatabase();
  }

  // Ensure the cache table exists
  void _initializeCacheTable() {
    _database.execute('''
      CREATE TABLE IF NOT EXISTS cache (
        keyword TEXT PRIMARY KEY,
        data TEXT,
        expirationDate DATETIME
      )
    ''');
  }

  // Load cache from the database
  void _loadCacheFromDatabase() {
    try {
      final cacheEntries = _database.select('SELECT * FROM cache');
      for (final row in cacheEntries) {
        final String keyword = row['keyword'] as String;
        final Map<String, dynamic> data = json.decode(row['data'] as String);

        // Convert expirationDate string to DateTime for proper handling
        data['expirationDate'] =
            DateTime.parse(row['expirationDate'] as String).toIso8601String();

        _cache[keyword] = data;
      }
    } catch (e) {
      print('Error loading cache from database: $e');
    }
  }

  Map<String, Map<String, dynamic>> get cache => _cache;

  void addToCache(
      String keyword, Map<String, dynamic> data, String expirationDate) {
    if (_cache.length >= maxCacheSize) {
      _evictOldestCacheEntry();
    }
    _cache[keyword] = data;

    _database.execute(
      'INSERT OR REPLACE INTO cache (keyword, data, expirationDate) VALUES (?, ?, ?)',
      [keyword, json.encode(data), expirationDate],
    );
  }

  Map<String, dynamic>? getFromCache(String keyword) {
    return _cache[keyword];
  }

  void updateCache(
      String keyword, Map<String, dynamic> updatedData, String expirationDate) {
    if (_cache.containsKey(keyword)) {
      _cache[keyword] = updatedData;

      _database.execute(
        'INSERT OR REPLACE INTO cache (keyword, data, expirationDate) VALUES (?, ?, ?)',
        [keyword, json.encode(updatedData), expirationDate],
      );
    }
  }

  void removeFromCache(String keyword) {
    _cache.remove(keyword);
    _database.execute('DELETE FROM cache WHERE keyword = ?', [keyword]);
  }

  void _evictOldestCacheEntry() {
    if (_cache.isNotEmpty) {
      final oldestKey = _cache.entries
          .reduce((a, b) => a.value['timestamp'] < b.value['timestamp'] ? a : b)
          .key;
      print('Evicting cache entry with key: $oldestKey');
      _cache.remove(oldestKey);
      _database.execute('DELETE FROM cache WHERE keyword = ?', [oldestKey]);
    }
  }

  void removeExpiredCacheEntries(DateTime now) {
    try {
      final String nowStr = now.toIso8601String();

      // Remove expired entries from the in-memory cache
      _cache.removeWhere((key, value) {
        final expirationDate =
            DateTime.parse(value['expirationDate'] as String);
        return expirationDate.isBefore(now);
      });

      // Remove expired entries from the database
      _database.execute(
        'DELETE FROM cache WHERE expirationDate < ?',
        [nowStr],
      );
    } catch (e) {
      print('Error removing expired cache entries: $e');
    }
  }
}

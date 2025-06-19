// code with error as on 28/11/24
// import 'dart:convert';

// import 'package:test/test.dart';
// import 'package:sqlite3/sqlite3.dart';
// import 'package:indexmgr/cachemgr.dart';

// void main() {
//   late Database database;
//   late B4CacheManager cacheManager;

//   setUp(() {
//     database = sqlite3.openInMemory();
//     cacheManager = B4CacheManager(database,
//         maxCacheSize: 5); // Set a small max size for testing
//   });

//   tearDown(() {
//     database.dispose();
//   });

//   test('Adds to cache and updates database', () {
//     final data = {'key': 'value'};
//     final expirationDate =
//         DateTime.now().add(Duration(days: 1)).toIso8601String();

//     cacheManager.addToCache('myKey', data, expirationDate);

//     // Verify in-memory cache
//     expect(cacheManager.cache['myKey'], data);

//     // Verify database entry
//     final result =
//         database.select('SELECT * FROM cache WHERE keyword = ?', ['myKey']);
//     expect(result.isNotEmpty, true);
//     expect(jsonDecode(result.first['data'] as String), data);
//   });

//   test('Gets from cache', () {
//     final data = {'key': 'value'};
//     final expirationDate =
//         DateTime.now().add(Duration(days: 1)).toIso8601String();
//     cacheManager.addToCache('myKey', data, expirationDate);

//     final cachedData = cacheManager.getFromCache('myKey');
//     expect(cachedData, data);
//   });

//   test('Updates cache and database', () {
//     final data = {'key': 'value'};
//     final expirationDate =
//         DateTime.now().add(Duration(days: 1)).toIso8601String();
//     cacheManager.addToCache('myKey', data, expirationDate);

//     final updatedData = {'key': 'newValue'};
//     cacheManager.updateCache('myKey', updatedData, expirationDate);

//     // Verify in-memory cache
//     expect(cacheManager.cache['myKey'], updatedData);

//     // Verify database update
//     final result =
//         database.select('SELECT * FROM cache WHERE keyword = ?', ['myKey']);
//     expect(result.isNotEmpty, true);
//     expect(jsonDecode(result.first['data'] as String), updatedData);
//   });

//   test('Removes from cache and database', () {
//     final data = {'key': 'value'};
//     final expirationDate =
//         DateTime.now().add(Duration(days: 1)).toIso8601String();
//     cacheManager.addToCache('myKey', data, expirationDate);

//     cacheManager.removeFromCache('myKey');

//     // Verify in-memory cache
//     expect(cacheManager.cache, isNot(contains('myKey')));

//     // Verify database deletion
//     final result =
//         database.select('SELECT * FROM cache WHERE keyword = ?', ['myKey']);
//     expect(result.isEmpty, true);
//   });

//   test('Evicts oldest entry when cache is full', () {
//     final expirationDate =
//         DateTime.now().add(Duration(days: 1)).toIso8601String();

//     // Add entries until the cache is full
//     for (int i = 0; i < cacheManager.maxCacheSize; i++) {
//       cacheManager.addToCache('key$i', {'value': i}, expirationDate);
//     }

//     // Add one more entry to trigger eviction
//     cacheManager.addToCache('key$cacheManager.maxCacheSize',
//         {'value': cacheManager.maxCacheSize}, expirationDate);

//     // Verify that the oldest entry is evicted
//     expect(cacheManager.cache.length, cacheManager.maxCacheSize);
//     expect(cacheManager.cache.containsKey('key0'), isFalse);
//   });

//   test('Removes expired entries', () {
//     final expiredDate =
//         DateTime.now().subtract(Duration(days: 1)).toIso8601String();
//     final validDate = DateTime.now().add(Duration(days: 1)).toIso8601String();

//     cacheManager.addToCache('expiredKey', {'value': 1}, expiredDate);
//     cacheManager.addToCache('validKey', {'value': 2}, validDate);

//     cacheManager.removeExpiredCacheEntries(DateTime.now());

//     expect(cacheManager.cache.length, 1);
//     expect(cacheManager.cache.containsKey('validKey'), true);
//     expect(cacheManager.cache.containsKey('expiredKey'), false);
//   });
// }

// import 'package:index_manager/cachemgr.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:indexmgr/cachemgr.dart';
//import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart';


void main() {
  late Database database;
  late B4CacheManager cacheManager;

  setUp(() {
    database = sqlite3.openInMemory(); // Use an in-memory database for testing
    cacheManager = B4CacheManager(database);
  });

  tearDown(() {
    database.dispose();
  });

  test('Add to Cache', () {
    final cacheData = {
      'keyword': 'cacheKeyword',
      'location': 'cacheLocation',
      'status': 'active'
    };
    cacheManager.addToCache(
        'cacheKeyword', cacheData, DateTime.now().toIso8601String());

    final result = database
        .select('SELECT * FROM cache WHERE keyword = ?', ['cacheKeyword']);
    expect(result.isNotEmpty, true);
    print('Cache entry added successfully.');
  });

  test('Get from Cache', () {
    final cacheData = {
      'keyword': 'getCacheKeyword',
      'location': 'getCacheLocation',
      'status': 'active'
    };
    cacheManager.addToCache(
        'getCacheKeyword', cacheData, DateTime.now().toIso8601String());

    final result = cacheManager.getFromCache('getCacheKeyword');
    expect(result, isNotNull);
    expect(result!['keyword'], 'getCacheKeyword');
    print('Cache entry retrieved successfully: $result');
  });

  test('Update Cache', () {
    final cacheData = {
      'keyword': 'updateCacheKeyword',
      'location': 'updateCacheLocation',
      'status': 'active'
    };
    cacheManager.addToCache(
        'updateCacheKeyword', cacheData, DateTime.now().toIso8601String());

    final updatedData = {
      'keyword': 'updateCacheKeyword',
      'location': 'updatedLocation',
      'status': 'inactive'
    };
    cacheManager.updateCache(
        'updateCacheKeyword', updatedData, DateTime.now().toIso8601String());

    final result = cacheManager.getFromCache('updateCacheKeyword');
    expect(result != null, true);
    expect(result!['location'], 'updatedLocation');
    print('Cache entry updated successfully.');
  });

  test('Remove from Cache', () {
    final cacheData = {
      'keyword': 'removeCacheKeyword',
      'location': 'removeCacheLocation',
      'status': 'active'
    };
    cacheManager.addToCache(
        'removeCacheKeyword', cacheData, DateTime.now().toIso8601String());

    cacheManager.removeFromCache('removeCacheKeyword');
    final result = database.select(
        'SELECT * FROM cache WHERE keyword = ?', ['removeCacheKeyword']);
    expect(result.isEmpty, true);
    print('Cache entry removed successfully.');
  });
}


// import 'dart:convert';
// import 'package:sqlite3/sqlite3.dart';

// class B4CacheManager {
//   final Database _database;
//   final int maxCacheSize;
//   final Map<String, Map<String, dynamic>> _cache = {};

//   B4CacheManager(this._database, {this.maxCacheSize = 10}) {
//     _initializeCacheTable();
//     _loadCacheFromDatabase();
//   }

//   // Ensure the cache table exists
//   void _initializeCacheTable() {
//     _database.execute('''
//       CREATE TABLE IF NOT EXISTS cache (
//         keyword TEXT PRIMARY KEY,
//         data TEXT,
//         expirationDate DATETIME,
//         timestamp INTEGER
//       )
//     ''');
//   }

//   // Load cache from the database
//   void _loadCacheFromDatabase() {
//     try {
//       final cacheEntries = _database.select('SELECT * FROM cache');
//       for (final row in cacheEntries) {
//         final String keyword = row['keyword'] as String;
//         final Map<String, dynamic> data = json.decode(row['data'] as String);

//         // Convert expirationDate string to DateTime for proper handling
//         data['expirationDate'] =
//             DateTime.parse(row['expirationDate'] as String).toIso8601String();
//         data['timestamp'] = row['timestamp'] as int;

//         _cache[keyword] = data;
//       }
//     } catch (e) {
//       print('Error loading cache from database: $e');
//     }
//   }

//   Map<String, Map<String, dynamic>> get cache => _cache;

//   void addToCache(
//       String keyword, Map<String, dynamic> data, String expirationDate) {
//     if (_cache.length >= maxCacheSize) {
//       _evictOldestCacheEntry();
//     }

//     data['timestamp'] = DateTime.now().millisecondsSinceEpoch;

//     _cache[keyword] = data;

//     _database.execute(
//       'INSERT OR REPLACE INTO cache (keyword, data, expirationDate, timestamp) VALUES (?, ?, ?, ?)',
//       [keyword, json.encode(data), expirationDate, data['timestamp']],
//     );
//   }

//   Map<String, dynamic>? getFromCache(String keyword) {
//     return _cache[keyword];
//   }

//   void updateCache(
//       String keyword, Map<String, dynamic> updatedData, String expirationDate) {
//     if (_cache.containsKey(keyword)) {
//       updatedData['timestamp'] = DateTime.now().millisecondsSinceEpoch;
//       _cache[keyword] = updatedData;

//       _database.execute(
//         'INSERT OR REPLACE INTO cache (keyword, data, expirationDate, timestamp) VALUES (?, ?, ?, ?)',
//         [
//           keyword,
//           json.encode(updatedData),
//           expirationDate,
//           updatedData['timestamp']
//         ],
//       );
//     }
//   }

//   void removeFromCache(String keyword) {
//     _cache.remove(keyword);
//     _database.execute('DELETE FROM cache WHERE keyword = ?', [keyword]);
//   }

//   void _evictOldestCacheEntry() {
//     if (_cache.isNotEmpty) {
//       final oldestKey = _cache.entries
//           .reduce((a, b) => a.value['timestamp'] < b.value['timestamp'] ? a : b)
//           .key;
//       print('Evicting cache entry with key: $oldestKey');
//       _cache.remove(oldestKey);
//       _database.execute('DELETE FROM cache WHERE keyword = ?', [oldestKey]);
//     }
//   }

//   void removeExpiredCacheEntries(DateTime now) {
//     try {
//       final String nowStr = now.toIso8601String();

//       // Remove expired entries from the in-memory cache
//       _cache.removeWhere((key, value) {
//         final expirationDate =
//             DateTime.parse(value['expirationDate'] as String);
//         return expirationDate.isBefore(now);
//       });

//       // Remove expired entries from the database
//       _database.execute(
//         'DELETE FROM cache WHERE expirationDate < ?',
//         [nowStr],
//       );
//     } catch (e) {
//       print('Error removing expired cache entries: $e');
//     }
//   }
// }

// import 'package:indexmgr/cachemgr.dart';

// import 'package:test/test.dart';
// import 'package:sqlite3/sqlite3.dart';

// void main() {
//   late Database database;
//   late B4CacheManager cacheManager;

//   setUp(() {
//     database = sqlite3.openInMemory(); // Use an in-memory database for testing
//     cacheManager = B4CacheManager(database);
//   });

//   tearDown(() {
//     database.dispose();
//   });

//   test('Add to Cache', () {
//     final cacheData = {
//       'keyword': 'cacheKeyword',
//       'location': 'cacheLocation',
//       'status': 'active'
//     };
//     cacheManager.addToCache(
//         'cacheKeyword', cacheData, DateTime.now().toIso8601String());

//     final result = database
//         .select('SELECT * FROM cache WHERE keyword = ?', ['cacheKeyword']);
//     expect(result.isNotEmpty, true);
//     print('Cache entry added successfully.');
//   });

//   test('Get from Cache', () {
//     final cacheData = {
//       'keyword': 'getCacheKeyword',
//       'location': 'getCacheLocation',
//       'status': 'active'
//     };
//     cacheManager.addToCache(
//         'getCacheKeyword', cacheData, DateTime.now().toIso8601String());

//     final result = cacheManager.getFromCache('getCacheKeyword');
//     expect(result, isNotNull);
//     expect(result!['keyword'], 'getCacheKeyword');
//     print('Cache entry retrieved successfully: $result');
//   });

//   test('Update Cache', () {
//     final cacheData = {
//       'keyword': 'updateCacheKeyword',
//       'location': 'updateCacheLocation',
//       'status': 'active'
//     };
//     cacheManager.addToCache(
//         'updateCacheKeyword', cacheData, DateTime.now().toIso8601String());

//     final updatedData = {
//       'keyword': 'updateCacheKeyword',
//       'location': 'updatedLocation',
//       'status': 'inactive'
//     };
//     cacheManager.updateCache(
//         'updateCacheKeyword', updatedData, DateTime.now().toIso8601String());

//     final result = cacheManager.getFromCache('updateCacheKeyword');
//     expect(result != null, true);
//     expect(result!['location'], 'updatedLocation');
//     print('Cache entry updated successfully.');
//   });

//   test('Remove from Cache', () {
//     final cacheData = {
//       'keyword': 'removeCacheKeyword',
//       'location': 'removeCacheLocation',
//       'status': 'active'
//     };
//     cacheManager.addToCache(
//         'removeCacheKeyword', cacheData, DateTime.now().toIso8601String());

//     cacheManager.removeFromCache('removeCacheKeyword');
//     final result = database.select(
//         'SELECT * FROM cache WHERE keyword = ?', ['removeCacheKeyword']);
//     expect(result.isEmpty, true);
//     print('Cache entry removed successfully.');
//   });
// }

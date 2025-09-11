///@version:1.0.0
///name:cachemgr_test
///author:

import 'package:indexmgr/cachemgr.dart';

/// Handy for writing and running tests.

import 'package:test/test.dart';

/// For working with SQLite databases.

import 'package:sqlite3/sqlite3.dart';

/// The main function for running cache manager tests.
///
/// It sets up an in-memory SQLite database and a `B4CacheManager` instance
///
/// before each test and disposes of the database after each test.

void main() {
  late Database database;

  ///Declare a late-initialized Database variable.

  late B4CacheManager cacheManager;

  ///Declare a late-initialized B4CacheManager variable
  ///
  /// Sets up the testing environment before each test case.
  ///
  /// Initializes an in-memory SQLite database and a `B4CacheManager` instance.

  setUp(() {

    ///Initialize an in-memory SQLite database.

    database = sqlite3.openInMemory();

    ///Initialize the cache manager with the in-memory database.

    cacheManager = B4CacheManager(database);
  });

  /// Tears down the testing environment after each test case.

  /// Disposes of the in-memory SQLite database to release resources.

  ///Dispose of the database connection.

  tearDown(() {
    database.dispose();
  });

  /// Test case for adding an entry to the cache.
  ///
  /// This test verifies that `addToCache` correctly stores data in both
  ///
  /// the in-memory cache and the underlying SQLite database.
  ///
  test('Add to Cache', () {

    ///Define the data to be cached.

    final cacheData = {

      ///Specify the keyword for the cache entry.

      'keyword': 'cacheKeyword',

      ///Specify the location data.

      'location': 'cacheLocation',

      ///Specify the status.

      'status': 'active',
    };
    cacheManager.addToCache(

      ///Call the addToCache method of the cacheManager.

      'cacheKeyword',

      ///The keyword under which the data will be stored.

      cacheData,


      ///The data map to be stored.
      ///
      ///The expiration date for the cache entry, converted to ISO 8601 string format.

      DateTime.now().toIso8601String(),
    );

    ///Verify that the data was written to the SQLite database.
    ///
    ///Execute a SELECT query on the 'cache' table.
    ///
    ///Use the keyword as a parameter to find the specific entry.

    final result = database.select('SELECT * FROM cache WHERE keyword = ?', [
      'cacheKeyword',
    ]);

    ///Assert that the query returned at least one row, meaning the entry exists.

    expect(result.isNotEmpty, true);

    ///Print a success message to the console.

    print('Cache entry added successfully.');
    cacheManager.removeFromCache('cacheKeyword');

    final deleteResult = database.select('SELECT * FROM cache WHERE keyword = ?', [
      'cacheKeyword',
    ]);

    ///Assert that the database query result is empty, confirming removal.

    expect(deleteResult.isEmpty, true);

    /// Print a success message.

    print('Cache entry removed successfully.');


  });

  /// Test case for retrieving an entry from the cache.
  ///
  /// This test ensures that `getFromCache` can successfully retrieve
  ///
  /// a previously added cache entry.

  test('Get from Cache', () {
    final cacheData = {

      ///Define the data for the cache entry.
      ///
      ///Specify the keyword for the entry.

      'keyword': 'getCacheKeyword',

      ///Specify the location data.

      'location': 'getCacheLocation',

      ///Add the defined data to the cache and database
      ///
      ///Specify the status.

      'status': 'active',
    };

    ///The keyword for the entry.

    cacheManager.addToCache(

      ///The data map to be cached.

      'getCacheKeyword', cacheData,

      ///The expiration date as an ISO 8601 string.

      DateTime.now().toIso8601String(),
    );

    /// Retrieve the entry from the cache using its keyword.

    final result = cacheManager.getFromCache('getCacheKeyword');

    ///Assert that the retrieved result is not null.

    expect(result, isNotNull);

    /// Assert that the keyword in the retrieved data matches the expected keyword.

    expect(result!['keyword'], 'getCacheKeyword');

    ///Print a success message along with the retrieved data.

    print('Cache entry retrieved successfully: $result');

    cacheManager.removeFromCache('getCacheKeyword');

    final deleteResult = database.select('SELECT * FROM cache WHERE keyword = ?', [
      'getCacheKeyword',
    ]);

    ///Assert that the database query result is empty, confirming removal.

    expect(deleteResult.isEmpty, true);

    /// Print a success message.

    print('Cache entry removed successfully.');
  });

  /// Test case for updating an existing entry in the cache.
  ///
  /// This test verifies that `updateCache` correctly modifies an existing
  ///
  /// entry in both the in-memory cache and the SQLite database,
  ///
  /// and that the updated data can be retrieved.
  test('Update Cache', () {

    /// Define the initial data for the cache entry.

    final cacheData = {

      ///Specify the keyword for the entry.

      'keyword': 'updateCacheKeyword',

      /// Specify the initial location data.

      'location': 'updateCacheLocation',

      ///Specify the initial status.

      'status': 'active',
    };

    ///
    ///Add the initial data to the cache and database.
    ///
    ///The keyword for the entry.
    ///
    ///The initial data map.

    cacheManager.addToCache(
      'updateCacheKeyword',
      cacheData,

      /// The expiration date as an ISO 8601 string.

      DateTime.now().toIso8601String(),
    );

    ///Define the updated data for the cache entry.
    ///
    /// The keyword remains the same.
    ///
    /// Specify the new location data.
    ///
    ///Specify the new status

    final updatedData = {
      'keyword': 'updateCacheKeyword',
      'location': 'updatedLocation',
      'status': 'inactive',
    };

    ///Call the method to update the cache entry.
    ///
    ///The keyword of the entry to update.
    ///
    ///The map containing the updated data.
    /// The new expiration date.

    cacheManager.updateCache(
      'updateCacheKeyword',
      updatedData,
      DateTime.now().toIso8601String(),
    );

    /// Retrieve the updated entry from the cache.

    final result = cacheManager.getFromCache('updateCacheKeyword');

    ///Assert that the retrieved result is not null.

    expect(result != null, true);

    ///Assert that the location in the retrieved data matches the updated location.

    expect(result!['location'], 'updatedLocation');

    ///Print a success message.

    print('Cache entry updated successfully.');
    cacheManager.removeFromCache('updateCacheKeyword');

    final deleteResult = database.select('SELECT * FROM cache WHERE keyword = ?', [
      'updateCacheKeyword',
    ]);

    ///Assert that the database query result is empty, confirming removal.

    expect(deleteResult.isEmpty, true);

    /// Print a success message.

    print('Cache entry removed successfully.');
  });

  ///updated on 13-06-2025
  ///this verifies that the B4CacheManager correctly creates a cache table in the provided SQLite database when it's initialized
  test('Initialize cache table', () {
    final database = sqlite3.openInMemory();

    ///this line creates a sqlite database that resides entirely in memory.

    B4CacheManager(database);

    /// calls _initializeCacheTable()

    final result = database.select(

      ///this sql querry means that, Show me the name of any table that is actually named 'cache'. Also if such a table exists, the query will return a row containing its name. If not, it will return an empty result

      "SELECT name FROM sqlite_master WHERE type='table' AND name='cache';",
    );

    ///here it is inferring that the result is not empty, and that the table 'cache' exists in the database

    expect(result.isNotEmpty, true);

    ///cleans up the database connection after the test is done

    database.dispose();
  });

  /// Test case for removing an entry from the cache.
  ///
  /// This test verifies that `removeFromCache` correctly removes data from both
  ///
  /// the in-memory cache and the underlying SQLite database.
  test('Remove from Cache', () {
    final cacheData = {

      ///Define the data for the cache entry.

      'keyword': 'removeCacheKeyword',

      ///Specify the keyword for the entry.

      'location': 'removeCacheLocation',

      ///Specify the location data.
      ///
      /// Specify the status.

      'status': 'active',
    };
    cacheManager.addToCache(

      ///Add the defined data to the cache and database.

      'removeCacheKeyword',

      ///The keyword for the entry.

      cacheData,

      ///The data map to be cached.
      /// The expiration date as an ISO 8601 string.

      DateTime.now().toIso8601String(),
    );

    /// Call the method to remove the entry by keyword.
    ///
    /// Query the database directly to check for the entry.
    ///
    ///Use the keyword as a parameter in the SQL query
    cacheManager.removeFromCache('removeCacheKeyword');

    final result = database.select('SELECT * FROM cache WHERE keyword = ?', [
      'removeCacheKeyword',
    ]);

    ///Assert that the database query result is empty, confirming removal.

    expect(result.isEmpty, true);

    /// Print a success message.

    print('Cache entry removed successfully.');
  });
}

//-----------------------------------------------------------------------------------commented part-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
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
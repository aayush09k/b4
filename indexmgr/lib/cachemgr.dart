
/// @Name:- Cachemgr
///
/// @author
///
/// @version 1.0.0
///


///Importing dart convert library for encoding/decoding.
import 'dart:convert';

/// Importing SQLite3 packages for SQLite database.
import 'package:sqlite3/sqlite3.dart';

/// Creating class [B4Cachemanager] and creating database instance
class B4CacheManager {
  final Database _database;
  final int maxCacheSize;
  final Map<String, Map<String, dynamic>> _cache = {};

  /// Creates a [B4CacheManager] constructor with the given [Database] instance.
  ///
  /// The [maxCacheSize] is optional and  by default is 10
  B4CacheManager(this._database, {this.maxCacheSize = 10}) {

    ///initializing cache table
    _initializeCacheTable();
    /// loading cache table from the given database
    _loadCacheFromDatabase();
  }

  /// function to create a Cache table if it was not created
  void _initializeCacheTable() {
    _database.execute('''
      CREATE TABLE IF NOT EXISTS cache (
        keyword TEXT PRIMARY KEY,
        data TEXT,
        expirationDate DATETIME
      )
    ''');
  }

  /// Function for Loading of cache from the database
  ///
  ///  If error occur, this message will be displayed ```Error loading cache from database```
  void _loadCacheFromDatabase() {
    try {

      ///using SQlite to retrieve all data from database.
      final cacheEntries = _database.select('SELECT * FROM cache');

      ///  For loop to get every single row data for further processing
      for (final row in cacheEntries) {

        final String keyword = row['keyword'] as String;
        /// decoding the JSON data and storing it as Map
        final Map<String, dynamic> data = json.decode(row['data'] as String);

        /// Convert expirationDate string to DateTime for proper handling
        data['expirationDate'] =
            DateTime.parse(row['expirationDate'] as String).toIso8601String();

        _cache[keyword] = data;
      }
    }
    /// If any error occur,print the error message
      catch (e) {
      print('Error loading cache from database: $e');
    }
  }
  /// function to get the cache data in [map]
  Map<String, Map<String, dynamic>> get cache => _cache;


  /// Function to get the database using getter method
  Database get database => _database;

  /// function to add data to the  cache memory
  bool addToCache(
      String keyword, Map<String, dynamic> data, String expirationDate) {
    try {
      /// Check if the cache is full THEN evict the oldest entry if necessary
      if (_cache.length >= maxCacheSize) {
        _evictOldestCacheEntry();
      }

      /// Add the entry to the cache
      _cache[keyword] = data;

      /// Insert into the database
      _database.execute(
        'INSERT OR REPLACE INTO cache (keyword, data, expirationDate) VALUES (?, ?, ?)',
        [keyword, json.encode(data), expirationDate],
      );
      /// Return true to indicate success
      return true;
    } catch (e) {
      /// Return false to indicate failure
      print('Failed to add entry to cache: $e');
      return false;
    }
  }



  /// Function to retrieve data from cache
  ///
  /// Returns [Map] containing cache data
  ///
  /// [keyword] is use to retrieve that particular data
  ///
  Map<String, dynamic>? getFromCache(String keyword) {
    return _cache[keyword];
  }

  /// Function to update cache with new data for the given keyword
  ///
  /// Entry is stored in [Map]
  ///
  /// Expiration date of the entry is stored in string format
  ///
  /// only update data if it exist in cache
  ///
  void updateCache(
      String keyword, Map<String, dynamic> updatedData, String expirationDate) {
    /// if that particular keyword exist in cache then,
    ///
    /// [updatedData] updated data will be assigned to that keyword
    ///
    /// Database will be executed to either insert or replace previous Data in the cache
    ///
    if (_cache.containsKey(keyword)) {
      _cache[keyword] = updatedData;

      _database.execute(
        'INSERT OR REPLACE INTO cache (keyword, data, expirationDate) VALUES (?, ?, ?)',
        [keyword, json.encode(updatedData), expirationDate],
      );
    }
  }

  /// Function to remove a particular data from cache if it exist
  void removeFromCache(String keyword) {
    /// Removes the entry with the given keyword from the in-memory cache
    _cache.remove(keyword);
    ///SQLite Query to delete data where given keyword matches with the keyword in-memory cache
    _database.execute('DELETE FROM cache WHERE keyword = ?', [keyword]);
  }


 /// Function to evict Oldest entry in the cache memory
  void _evictOldestCacheEntry() {
    /// If cache memory is not empty then, evict the oldest entry base on timestamp
    if (_cache.isNotEmpty) {
      final oldestKey = _cache.entries
          .reduce((a, b) => a.value['timestamp'] < b.value['timestamp'] ? a : b)
          .key;
      print('Evicting cache entry with key: $oldestKey');
      _cache.remove(oldestKey);
      /// Delete the oldest data from cache memory
      _database.execute('DELETE FROM cache WHERE keyword = ?', [oldestKey]);
    }
  }


  /// Function to remove the expired data from cache memory
  void removeExpiredCacheEntries(DateTime now) {
    try {
      /// Convert the current time to an ISO 8601 string for database comparison

      final String nowStr = now.toIso8601String();
      ///It iterate for each entry once and removed if it is expired
      _cache.removeWhere((key, value) {
        final expirationDate =
            DateTime.parse(value['expirationDate'] as String);
        return expirationDate.isBefore(now);
      });

      /// Remove expired entries from the database
      _database.execute(
        'DELETE FROM cache WHERE expirationDate < ?',
        [nowStr],
      );
    }
    /// If error occur, will display the error message
      catch (e) {
      print('Error removing expired cache entries: $e');
    }
  }
}


//----------------------------------------------------------------------------------------------------
// from here to last all the commented part of the code/code segment are there.
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

//---------------------- as on 10/12/2024---------------------------------
// void addToCache(
//     String keyword, Map<String, dynamic> data, String expirationDate) {
//   if (_cache.length >= maxCacheSize) {
//     _evictOldestCacheEntry();
//   }
//   _cache[keyword] = data;

//   _database.execute(
//     'INSERT OR REPLACE INTO cache (keyword, data, expirationDate) VALUES (?, ?, ?)',
//     [keyword, json.encode(data), expirationDate],
//   );
// }

// void addToCache(
//     String keyword, Map<String, dynamic> data, String expirationDate) {
//   if (_cache.length >= maxCacheSize) {
//     _evictOldestCacheEntry();
//   }
//   _cache[keyword] = data;

//   _database.execute(
//     'INSERT OR REPLACE INTO cache (keyword, data, expirationDate) VALUES (?, ?, ?)',
//     [keyword, json.encode(data), expirationDate],
//   );
// }
//---------------------------------------------------------------------------------------------------
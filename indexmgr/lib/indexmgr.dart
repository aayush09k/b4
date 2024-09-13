library indexmgr;
/*
/// A Calculator.
class Calculator {
  /// Returns [value] plus 1.
  int addOne(int value) => value + 1;
}
*/
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:sqlite3/sqlite3.dart';
import 'cache_manager.dart'; // Import the Cache Manager

// Initialize Logger
final Logger _logger = Logger('B4IndexManager');

void _initializeLogging() {
  Logger.root.level = Level.ALL; // Set logging level
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
}

class B4IndexManager {
  late final Database _database;
  late final B4CacheManager _cacheManager;
  final String dbPath;

  int maxCacheSize = 10; // Default max cache size
  // Add a getter to access _cacheManager in tests
  B4CacheManager getCacheManager() => _cacheManager;

  B4IndexManager(this.dbPath) {
    _initializeLogging(); // Initialize logging
    _initializeDatabase().then((_) {
      _cacheManager = B4CacheManager(_database,
          maxCacheSize: maxCacheSize); // Initialize the cache manager
      schedulePurgeTask();
    }).catchError((e) {
      _logger.severe('Initialization error: $e');
    });
  }

  // Initialization of the database
  Future<void> _initializeDatabase() async {
    try {
      final directory = Directory('database');
      if (!directory.existsSync()) {
        directory.createSync();
      }

      final dbPath = 'database/init.db';
      _database = sqlite3.open(dbPath, mode: OpenMode.readWriteCreate);

      _database.execute('''
        CREATE TABLE IF NOT EXISTS indexes (
          indexID INTEGER PRIMARY KEY AUTOINCREMENT,
          keyword TEXT,
          location TEXT,
          replicationFactor INTEGER,
          copyNo INTEGER,
          layerID INTEGER,
          status STRING,
          entryDateTime DATETIME,
          expirationDate DATETIME,
          publishTime DATETIME,
          republishTime DATETIME,
          timer TEXT DEFAULT '20m',
          lastUpdateTime DATETIME
        )
      ''');
      _database.execute('''
        CREATE TABLE IF NOT EXISTS purge (
          indexID INTEGER PRIMARY KEY AUTOINCREMENT,
          keyword TEXT,
          location TEXT,
          replicationFactor INTEGER,
          copyNo INTEGER,
          layerID INTEGER,
          status STRING,
          entryDateTime DATETIME,
          expirationDate DATETIME,
          publishTime DATETIME,
          republishTime DATETIME,
          timer TEXT,
          deletedAt DATETIME
        )
      ''');
      _database.execute('''
        CREATE TABLE IF NOT EXISTS cache (
          keyword TEXT PRIMARY KEY,
          data TEXT,
          expirationDate DATETIME
        )
      ''');
    } catch (e) {
      _logger.severe('Database initialization error: $e');
    }
  }

  DateTime getDateTime() => DateTime.now();

  String dateToString(DateTime date) => date.toIso8601String();

  DateTime stringToDate(String dateStr) => DateTime.parse(dateStr);

  Future<void> insertIndex(Map<String, dynamic> indexData) async {
    try {
      final DateTime now = getDateTime();
      final String nowStr = dateToString(now);

      final String publishTime = indexData['publishTime'] ?? nowStr;
      final String lastUpdateTime = indexData['lastUpdateTime'] ?? nowStr;

      final DateTime expirationDate = indexData['lastUpdateTime'] == null
          ? stringToDate(indexData['entryDateTime']).add(Duration(days: 30))
          : stringToDate(indexData['lastUpdateTime']).add(Duration(days: 30));

      final DateTime republishTime = stringToDate(publishTime).add(
        Duration(
            minutes: int.parse(
                indexData['timer']?.replaceAll(RegExp(r'[^0-9]'), '') ?? '20')),
      );

      _database.execute(
        'INSERT OR REPLACE INTO indexes (keyword, location, replicationFactor, copyNo, layerID, status, '
        'entryDateTime, expirationDate, publishTime, republishTime, timer, lastUpdateTime) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          indexData['keyword'],
          indexData['location'],
          indexData['replicationFactor'],
          indexData['copyNo'],
          indexData['layerID'],
          indexData['status'],
          nowStr,
          dateToString(expirationDate),
          publishTime,
          dateToString(republishTime),
          indexData['timer'] ?? '20m',
          lastUpdateTime,
        ],
      );

      // Add to cache using Cache Manager
      _cacheManager.addToCache(
          indexData['keyword'], indexData, dateToString(expirationDate));
    } catch (e) {
      _logger.severe('SQLite Exception during insert: $e');
    }
  }

  Future<Map<String, dynamic>?> readByKeyword(String keyword) async {
    final DateTime newExpirationDate = getDateTime().add(Duration(days: 30));

    // Check the cache using Cache Manager
    final cachedData = _cacheManager.getFromCache(keyword);
    if (cachedData != null) {
      // Update expiration date in cache
      _cacheManager.updateCache(
          keyword,
          {
            ...cachedData,
            'expirationDate': dateToString(newExpirationDate),
          },
          dateToString(newExpirationDate));
      return cachedData;
    }

    // Check the indexes table
    final indexResult =
        _database.select('SELECT * FROM indexes WHERE keyword = ?', [keyword]);

    if (indexResult.isNotEmpty) {
      final row = indexResult.first;
      final result = {
        'indexID': row['indexID'],
        'keyword': row['keyword'],
        'location': row['location'],
        'replicationFactor': row['replicationFactor'],
        'copyNo': row['copyNo'],
        'layerID': row['layerID'],
        'status': row['status'],
        'entryDateTime': row['entryDateTime'],
        'expirationDate': dateToString(newExpirationDate),
        'publishTime': row['publishTime'],
        'republishTime': row['republishTime'],
        'timer': row['timer'],
        'lastUpdateTime': row['lastUpdateTime'],
      };

      // Add to cache using Cache Manager
      _cacheManager.addToCache(
          keyword, result, dateToString(newExpirationDate));

      return result;
    }

    // Check the purge table
    final purgeResult =
        _database.select('SELECT * FROM purge WHERE keyword = ?', [keyword]);

    if (purgeResult.isNotEmpty) {
      await restoreIndexFromPurge(keyword);
      return _cacheManager.getFromCache(keyword);
    }

    return null;
  }

  Future<void> updateIndex(
      Map<String, dynamic> indexData, String updatedLocation) async {
    try {
      final DateTime expirationDate = indexData['lastUpdateTime'] == null
          ? stringToDate(
                  indexData['entryDateTime'] ?? DateTime.now().toString())
              .add(Duration(days: 30))
          : add24Hours(stringToDate(
              indexData['lastUpdateTime'] ?? DateTime.now().toString()));

      final DateTime republishTime = add12Months(stringToDate(
              indexData['publishTime'] ?? DateTime.now().toString()))
          .add(Duration(
              minutes: int.parse(
                  indexData['timer']?.replaceAll(RegExp(r'[^0-9]'), '') ??
                      '20')));

      final DateTime lastUpdateTime = DateTime.now();

      _database.execute(
        'UPDATE indexes SET location = ?, expirationDate = ?, republishTime = ?, lastUpdateTime = ? WHERE keyword = ?',
        [
          updatedLocation,
          dateToString(expirationDate),
          dateToString(republishTime),
          dateToString(lastUpdateTime),
          indexData['keyword']
        ],
      );

      // Update cache using Cache Manager
      _cacheManager.updateCache(
          indexData['keyword'],
          {
            ...indexData,
            'location': updatedLocation,
            'expirationDate': dateToString(expirationDate),
            'republishTime': dateToString(republishTime),
            'lastUpdateTime': dateToString(lastUpdateTime),
          },
          dateToString(expirationDate));
    } catch (e) {
      _logger.severe('SQLite Exception during update: $e');
    }
  }

  Future<void> deleteIndex(String keyword) async {
    try {
      final indexResult = _database
          .select('SELECT * FROM indexes WHERE keyword = ?', [keyword]);

      if (indexResult.isNotEmpty) {
        final row = indexResult.first;
        final DateTime now = DateTime.now();
        final purgeData = {
          'keyword': row['keyword'],
          'location': row['location'],
          'replicationFactor': row['replicationFactor'],
          'copyNo': row['copyNo'],
          'layerID': row['layerID'],
          'status': 'deleted',
          'entryDateTime': row['entryDateTime'],
          'expirationDate': row['expirationDate'],
          'publishTime': row['publishTime'],
          'republishTime': row['republishTime'],
          'timer': row['timer'],
          'deletedAt': dateToString(now),
        };

        _database.execute(
          'INSERT INTO purge (keyword, location, replicationFactor, copyNo, layerID, status, entryDateTime, expirationDate, publishTime, republishTime, timer, deletedAt) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            purgeData['keyword'],
            purgeData['location'],
            purgeData['replicationFactor'],
            purgeData['copyNo'],
            purgeData['layerID'],
            purgeData['status'],
            purgeData['entryDateTime'],
            purgeData['expirationDate'],
            purgeData['publishTime'],
            purgeData['republishTime'],
            purgeData['timer'],
            purgeData['deletedAt']
          ],
        );

        _database.execute(
          'DELETE FROM indexes WHERE keyword = ?',
          [keyword],
        );

        // Remove from cache using Cache Manager
        _cacheManager.removeFromCache(keyword);
      }
    } catch (e, stackTrace) {
      _logger.severe(
          'Failed to delete index with keyword "$keyword". Error: $e',
          e,
          stackTrace);
    }
  }

  Future<void> restoreIndexFromPurge(String keyword) async {
    try {
      final purgeResult =
          _database.select('SELECT * FROM purge WHERE keyword = ?', [keyword]);

      if (purgeResult.isNotEmpty) {
        final row = purgeResult.first;
        final now = DateTime.now();
        final restoredData = {
          'keyword': row['keyword'],
          'location': row['location'],
          'replicationFactor': row['replicationFactor'],
          'copyNo': row['copyNo'],
          'layerID': row['layerID'],
          'status': 'publish',
          'entryDateTime': row['entryDateTime'],
          'expirationDate': row['expirationDate'],
          'publishTime': row['publishTime'],
          'republishTime': row['republishTime'],
          'timer': row['timer'],
          'lastUpdateTime': dateToString(now),
        };

        _database.execute(
          'INSERT INTO indexes (keyword, location, replicationFactor, copyNo, layerID, status, entryDateTime, expirationDate, publishTime, republishTime, timer, lastUpdateTime) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            restoredData['keyword'],
            restoredData['location'],
            restoredData['replicationFactor'],
            restoredData['copyNo'],
            restoredData['layerID'],
            restoredData['status'],
            restoredData['entryDateTime'],
            restoredData['expirationDate'],
            restoredData['publishTime'],
            restoredData['republishTime'],
            restoredData['timer'],
            restoredData['lastUpdateTime']
          ],
        );

        // Add to cache using Cache Manager
        _cacheManager.addToCache(restoredData['keyword'], restoredData,
            dateToString(stringToDate(restoredData['expirationDate'])));
      }
    } catch (e) {
      _logger.severe(
          'Failed to restore index from purge for keyword "$keyword". Error: $e');
    }
  }

  // Scheduling the periodic purge task
  void schedulePurgeTask() {
    Timer.periodic(Duration(minutes: 20), (timer) {
      _purgeExpiredIndexes();
    });
  }

  // Purging expired indexes
  // Public method to handle purging
  Future<void> purgeExpiredIndexes() async {
    _purgeExpiredIndexes(); // This call should not be awaited
  }

  // Private method for purging expired indexes
  void _purgeExpiredIndexes() {
    final DateTime now = DateTime.now();

    // Delete expired indexes from the database
    _database.execute('DELETE FROM indexes WHERE expirationDate < ?',
        [now.toIso8601String()]);

    // Remove expired entries from the cache
    _cacheManager.removeExpiredCacheEntries(now);
  }

  // Helper function to add 24 hours to a DateTime
  DateTime add24Hours(DateTime dateTime) => dateTime.add(Duration(hours: 24));

  // Helper function to add 12 months to a DateTime
  DateTime add12Months(DateTime dateTime) {
    final int newYear = dateTime.year + (dateTime.month + 12) ~/ 12;
    final int newMonth = (dateTime.month + 12) % 12;
    final int newDay = dateTime.day;
    return DateTime(newYear, newMonth, newDay, dateTime.hour, dateTime.minute,
        dateTime.second);
  }

  // Methods for hash and republish can be implemented here
  Future<void> publishIndex(Map<String, dynamic> indexData) async {
    try {
      final DateTime now = getDateTime();
      final String nowStr = dateToString(now);

      final String publishTime = nowStr;
      final DateTime expirationDate = now.add(Duration(days: 30));
      final String hash = computeHash(indexData['location']);

      final DateTime republishTime = now.add(
        Duration(
            minutes: int.parse(
                indexData['timer']?.replaceAll(RegExp(r'[^0-9]'), '') ?? '20')),
      );

      _database.execute(
        'INSERT INTO indexes (keyword, location, replicationFactor, copyNo, layerID, status, entryDateTime, expirationDate, publishTime, republishTime, timer, lastUpdateTime) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          indexData['keyword'],
          hash, // Store the hash of the location
          indexData['replicationFactor'],
          indexData['copyNo'],
          indexData['layerID'],
          'publish',
          nowStr,
          dateToString(expirationDate),
          publishTime,
          dateToString(republishTime),
          indexData['timer'] ?? '20m',
          nowStr,
        ],
      );

      // Add to cache using Cache Manager
      _cacheManager.addToCache(
          indexData['keyword'],
          {
            ...indexData,
            'location': hash,
            'status': 'publish',
            'entryDateTime': nowStr,
            'expirationDate': dateToString(expirationDate),
            'publishTime': publishTime,
            'republishTime': dateToString(republishTime),
            'lastUpdateTime': nowStr,
          },
          dateToString(expirationDate));
    } catch (e) {
      _logger.severe('Failed to publish index  "$indexData". Error: $e');
    }
  }

  Future<void> republishIndex(String keyword) async {
    try {
      final DateTime now = getDateTime();
      final String nowStr = dateToString(now);
      final DateTime newExpirationDate = now.add(Duration(days: 30));

      final indexResult = _database.select(
        'SELECT * FROM indexes WHERE keyword = ?',
        [keyword],
      );

      if (indexResult.isNotEmpty) {
        final row = indexResult.first;

        final DateTime republishTime = now.add(
          Duration(
              minutes: int.parse(
                  row['timer']?.replaceAll(RegExp(r'[^0-9]'), '') ?? '20')),
        );

        _database.execute(
          'UPDATE indexes SET republishTime = ?, expirationDate = ? WHERE keyword = ?',
          [
            dateToString(republishTime),
            dateToString(newExpirationDate),
            keyword
          ],
        );

        // Update cache using Cache Manager
        final updatedData = {
          'indexID': row['indexID'],
          'keyword': row['keyword'],
          'location': row['location'],
          'replicationFactor': row['replicationFactor'],
          'copyNo': row['copyNo'],
          'layerID': row['layerID'],
          'status': 'publish',
          'entryDateTime': row['entryDateTime'],
          'expirationDate': dateToString(newExpirationDate),
          'publishTime': row['publishTime'],
          'republishTime': dateToString(republishTime),
          'timer': row['timer'],
          'lastUpdateTime': nowStr,
        };

        _cacheManager.updateCache(
            keyword, updatedData, dateToString(newExpirationDate));
      }
    } catch (e) {
      _logger.severe(
          'Failed to republish index with keyword "$keyword". Error: $e');
    }
  }

  String computeHash(String data) {
    try {
      final bytes = utf8.encode(data);
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      _logger.severe('Failed to compute hash for data "$data". Error: $e');
      rethrow;
    }
  }

  void dispose() {
    _database.dispose(); // Ensure the database connection is closed
  }

  Future<void> purgeDeletedIndexes() async {
    try {
      final now = DateTime.now();

      // Move deleted indexes to the purge table
      final deletedIndexes = _database
          .select('SELECT * FROM indexes WHERE status = ?', ['deleted']);

      if (deletedIndexes.isNotEmpty) {
        for (var row in deletedIndexes) {
          _database.execute(
              'INSERT INTO purge (keyword, location, replicationFactor, copyNo, layerID, status, entryDateTime, expirationDate, publishTime, republishTime, timer, deletedAt) '
              'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
              [
                row['keyword'],
                row['location'],
                row['replicationFactor'],
                row['copyNo'],
                row['layerID'],
                'deleted',
                row['entryDateTime'],
                row['expirationDate'],
                row['publishTime'],
                row['republishTime'],
                row['timer'],
                dateToString(now),
              ]);
        }

        // Remove the deleted indexes from the indexes table
        _database.execute('DELETE FROM indexes WHERE status = ?', ['deleted']);
      }
    } catch (e) {
      _logger.severe('Failed to purge deleted entries. Error: $e');
    }
  }
}

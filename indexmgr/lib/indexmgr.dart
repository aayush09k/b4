import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:sqlite3/sqlite3.dart';
import 'cachemgr.dart'; // Import the Cache Manager

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

  B4IndexManager({this.dbPath = 'database/index_olm.db'}) {
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

      // final dbPath = 'database/init.db';
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
      // Extract the fields sent from OLM
      final String keyword = indexData['keyword'];
      final String location = indexData['location'];
      final int copyNo = indexData['copyNo'] ?? 0;
      // final int totCopies = indexData['totCopies'] ?? 1;//
      //still in question how it is related to the code??
      // may be to calculate the total copies number

      // Set defaults for fixed fields
      final int replicationFactor = 2; // Set replication factor to 2
      final int layerID = 1; // Set layer ID to 1
      final String status = 'active'; // Status is initially 'active'

      // Get the current date and time
      final DateTime now = getDateTime();
      final String nowStr = dateToString(now);

      // Use passed in publishTime or the current time
      final String publishTime = indexData['publishTime'] ?? nowStr;
      final String lastUpdateTime = indexData['lastUpdateTime'] ?? nowStr;

      // Calculate expiration date (30 days from entry or last update time)
      final DateTime expirationDate = indexData['lastUpdateTime'] == null
          ? stringToDate(indexData['entryDateTime']).add(Duration(days: 30))
          : stringToDate(indexData['lastUpdateTime']).add(Duration(days: 30));

      // Calculate republish time (e.g., 20 minutes after publish time)
      final DateTime republishTime = stringToDate(publishTime).add(
        Duration(
            minutes: int.parse(
                indexData['timer']?.replaceAll(RegExp(r'[^0-9]'), '') ?? '20')),
      );

      // Insert or replace into the database
      _database.execute(
        'INSERT OR REPLACE INTO indexes (indexID, keyword, location, replicationFactor, copyNo, layerID, status, '
        'entryDateTime, expirationDate, publishTime, republishTime, timer, lastUpdateTime) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          indexData['indexID'], // Pass the index_id here
          keyword,
          location,
          replicationFactor, // Fixed replication factor
          copyNo,
          layerID, // Fixed layer ID
          status, // Active status
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

      _logger.info(
          'Index entry inserted or updated successfully: ${indexData['keyword']}');
    } catch (e) {
      _logger.severe('SQLite Exception during insert: $e');
    }
  }

  // Future<void> insertIndex(Map<String, dynamic> indexData) async {
  //   try {
  //     final DateTime now = getDateTime();
  //     final String nowStr = dateToString(now);

  //     final String publishTime = indexData['publishTime'] ?? nowStr;
  //     final String lastUpdateTime = indexData['lastUpdateTime'] ?? nowStr;

  //     final DateTime expirationDate = indexData['lastUpdateTime'] == null
  //         ? stringToDate(indexData['entryDateTime']).add(Duration(days: 30))
  //         : stringToDate(indexData['lastUpdateTime']).add(Duration(days: 30));

  //     final DateTime republishTime = stringToDate(publishTime).add(
  //       Duration(
  //           minutes: int.parse(
  //               indexData['timer']?.replaceAll(RegExp(r'[^0-9]'), '') ?? '20')),
  //     );

  //     final int replicationFactor = 2; // Set replication factor to 2

  //     _database.execute(
  //       'INSERT OR REPLACE INTO indexes (keyword, location, replicationFactor, copyNo, layerID, status, '
  //       'entryDateTime, expirationDate, publishTime, republishTime, timer, lastUpdateTime) '
  //       'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
  //       [
  //         indexData['keyword'],
  //         indexData['location'],
  //         replicationFactor, // Set replication factor to 2
  //         indexData['copyNo'],
  //         indexData['layerID'],
  //         'active', // Status is set to "active" initially
  //         nowStr,
  //         dateToString(expirationDate),
  //         publishTime,
  //         dateToString(republishTime),
  //         indexData['timer'] ?? '20m',
  //         lastUpdateTime,
  //       ],
  //     );

  //     // Add to cache using Cache Manager
  //     _cacheManager.addToCache(
  //         indexData['keyword'], indexData, dateToString(expirationDate));
  //   } catch (e) {
  //     _logger.severe('SQLite Exception during insert: $e');
  //   }
  // }

  Future<Map<String, dynamic>?> readByKeyword(String keyword,
      {bool partialSearch = false}) async {
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

    // Construct the SQL query based on whether partial search is needed
    final String query;
    final List<dynamic> parameters;

    if (partialSearch) {
      query = 'SELECT * FROM indexes WHERE keyword LIKE ?';
      parameters = ['%$keyword%'];
    } else {
      query = 'SELECT * FROM indexes WHERE keyword = ?';
      parameters = [keyword];
    }

    // Check the indexes table
    final indexResult = _database.select(query, parameters);

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
    final purgeQuery = partialSearch
        ? 'SELECT * FROM purge WHERE keyword LIKE ?'
        : 'SELECT * FROM purge WHERE keyword = ?';
    final purgeParameters = partialSearch ? ['%$keyword%'] : [keyword];

    final purgeResult = _database.select(purgeQuery, purgeParameters);

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
          'active', // Update status to "active"
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
            'status': 'active', // Update status to "active"
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

  Future<void> publishIndex(
      Map<String, dynamic> indexData, String serverSignedCertificate) async {
    try {
      final DateTime now = getDateTime();
      final String nowStr = dateToString(now);
      final String publishTime = nowStr;
      final DateTime expirationDate = now.add(Duration(days: 30));
      final String hash = computeHash(indexData['location']);

      final DateTime republishTime = now.add(
        Duration(
          minutes: int.parse(
            indexData['timer']?.replaceAll(RegExp(r'[^0-9]'), '') ?? '20',
          ),
        ),
      );

      // Insert the index data into the database
      _database.execute(
        'INSERT INTO indexes (keyword, location, replicationFactor, copyNo, layerID, status, entryDateTime, expirationDate, publishTime, republishTime, timer, lastUpdateTime) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          indexData['keyword'],
          hash, // Store the hash of the location
          indexData['replicationFactor'],
          indexData['copyNo'],
          indexData['layerID'],
          'active',
          nowStr,
          dateToString(expirationDate),
          publishTime,
          dateToString(republishTime),
          indexData['timer'] ?? '20m',
          nowStr,
          //serverSignedCertificate, // Insert the server-signed certificate
        ],
      );

      // Add to cache using Cache Manager
      _cacheManager.addToCache(
        indexData['keyword'],
        {
          ...indexData,
          'location': hash,
          'status': 'active',
          'entryDateTime': nowStr,
          'expirationDate': dateToString(expirationDate),
          'publishTime': publishTime,
          'republishTime': dateToString(republishTime),
          'lastUpdateTime': nowStr,
          //'serverSignedCertificate': serverSignedCertificate, // Add to cache
        },
        dateToString(expirationDate),
      );
    } catch (e) {
      _logger.severe('Failed to publish index "$indexData". Error: $e');
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
          'status': 'active',
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

// Function to handle purging of expired and deleted indexes
  Future<void> _purgeIndexes() async {
    final DateTime now = DateTime.now();

    try {
      // Step 1: Fetch and move expired indexes to the purge table
      final expiredIndexes = await _database.select(
        'SELECT * FROM indexes WHERE expirationDate < ?',
        [now.toIso8601String()],
      );

      for (final index in expiredIndexes) {
        // Insert expired indexes into the purge table
        _database.execute(
          'INSERT INTO purge (keyword, location, replicationFactor, copyNo, layerID, status, entryDateTime, expirationDate, publishTime, republishTime, timer, deletedAt) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            index['keyword'],
            index['location'],
            index['replicationFactor'],
            index['copyNo'],
            index['layerID'],
            'deleted', // Mark as deleted
            index['entryDateTime'],
            index['expirationDate'],
            index['publishTime'],
            index['republishTime'],
            index['timer'],
            dateToString(now), // Log the purge timestamp
          ],
        );

        // Remove expired indexes from the main indexes table
        _database.execute(
            'DELETE FROM indexes WHERE keyword = ?', [index['keyword']]);
      }

      // Step 2: Handle explicitly deleted indexes
      final deletedIndexes = await _database.select(
        'SELECT * FROM indexes WHERE status = ?',
        ['deleted'],
      );

      for (final index in deletedIndexes) {
        // Insert deleted indexes into the purge table
        _database.execute(
          'INSERT INTO purge (keyword, location, replicationFactor, copyNo, layerID, status, entryDateTime, expirationDate, publishTime, republishTime, timer, deletedAt) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            index['keyword'],
            index['location'],
            index['replicationFactor'],
            index['copyNo'],
            index['layerID'],
            'deleted', // Keep as deleted
            index['entryDateTime'],
            index['expirationDate'],
            index['publishTime'],
            index['republishTime'],
            index['timer'],
            dateToString(now), // Log the purge timestamp
          ],
        );

        // Remove deleted indexes from the main indexes table
        _database.execute(
            'DELETE FROM indexes WHERE keyword = ?', [index['keyword']]);
      }

      // Step 3: Remove expired entries from the cache
      _cacheManager.removeExpiredCacheEntries(now);

      _logger.info('Purged expired and deleted indexes successfully.');
    } catch (e) {
      _logger.severe('Failed to purge indexes. Error: $e');
    }
  }

// Public method to trigger purging manually
  Future<void> purgeIndexes() async {
    await _purgeIndexes();
  }

// Scheduling the periodic purge task
  void schedulePurgeTask() {
    Timer.periodic(Duration(minutes: 20), (timer) async {
      await _purgeIndexes(); // Periodically purge indexes
    });
  }

// Function to restore an index from the purge table
  Future<void> restoreIndexFromPurge(String keyword) async {
    try {
      final purgeResult =
          _database.select('SELECT * FROM purge WHERE keyword = ?', [keyword]);

      if (purgeResult.isNotEmpty) {
        final row = purgeResult.first;
        final now = DateTime.now();

        // Prepare the restored data
        final restoredData = {
          'keyword': row['keyword'],
          'location': row['location'],
          'replicationFactor': row['replicationFactor'],
          'copyNo': row['copyNo'],
          'layerID': row['layerID'],
          'status': 'active', // Restore as active
          'entryDateTime': row['entryDateTime'],
          'expirationDate': row['expirationDate'],
          'publishTime': row['publishTime'],
          'republishTime': row['republishTime'],
          'timer': row['timer'],
          'lastUpdateTime': dateToString(now), // Update timestamp
        };

        // Insert restored data back into the indexes table
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
            restoredData['lastUpdateTime'],
          ],
        );

        // Remove the restored entry from the purge table
        _database.execute('DELETE FROM purge WHERE keyword = ?', [keyword]);

        // Add restored entry to the cache
        _cacheManager.addToCache(
          restoredData['keyword'],
          restoredData,
          dateToString(stringToDate(restoredData['expirationDate'])),
        );

        _logger.info(
            'Successfully restored index from purge for keyword "$keyword".');
      } else {
        _logger.warning(
            'No matching record found in purge table for keyword "$keyword".');
      }
    } catch (e) {
      _logger.severe(
          'Failed to restore index from purge for keyword "$keyword". Error: $e');
    }
  }
}

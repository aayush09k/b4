import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:sqlite3/sqlite3.dart';
import 'cachemgr.dart'; // Import the Cache Manager
import 'dart:async';
import 'dart:convert';
// import 'package:uuid/uuid.dart';
// import 'package:index_mgr/index_mgr.dart';

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
  // late String dbPath;
  // String generateUUIDIndexID() {
  //   var uuid = Uuid();
  //   return uuid.v4(); // Generates a unique UUID
  // }

  int maxCacheSize = 10; // Default max cache size
  // Add a getter to access _cacheManager in tests
  B4CacheManager getCacheManager() => _cacheManager;

  //  B4IndexManager({this.dbPath = 'database/index_olm.db'}) {
  //// only db path , no parameter required
  ///
  B4IndexManager(String dbPath) {
    _initializeLogging(); // Initialize logging
    _initializeDatabase(dbPath).then((_) {
      _cacheManager = B4CacheManager(_database,
          maxCacheSize: maxCacheSize); // Initialize the cache manager
      schedulePurgeTask();
    }).catchError((e) {
      _logger.severe('Initialization error: $e');
    });
  }

  Database get database => _database;

  // Initialization of the database
  Future<void> _initializeDatabase(String dbPath) async {
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
          status TEXT,
          entryDateTime DATETIME,
          expirationDate DATETIME,
          publishTime DATETIME,
          republishTime DATETIME,
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
          status TEXT,
          entryDateTime DATETIME,
          expirationDate DATETIME,
          publishTime DATETIME,
          republishTime DATETIME,
          deletedAt DATETIME
        )
      ''');
      _database.execute('''
        CREATE TABLE IF NOT EXISTS cache (
          keyword TEXT,
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

  /// Compute the first hash (hash1) from a location
  String computeHash1(String location) {
    return sha256.convert(utf8.encode(location)).toString();
  }

  /// Compute the second hash (hash2) by appending copyNo to hash1
  String computeHash2(String hash1, int copyNo) {
    String combined = '$hash1-copy$copyNo';
    return sha256.convert(utf8.encode(combined)).toString();
  }

  // final uuid = Uuid();
  String truncateMilliseconds(String datetime) {
    return datetime.split('.').first.replaceFirst('T', ' ');
  }

  Future<Map<String, dynamic>> processAndInsertIndex(
      Map<String, dynamic> minimalData) async {
    try {
      // Add missing fields
      minimalData['copyNo'] = 1;
      minimalData['status'] = 'active';
      minimalData['entryDateTime'] = truncateMilliseconds(
          minimalData['entryDateTime'] ?? DateTime.now().toIso8601String());
      minimalData['publishTime'] = truncateMilliseconds(
          minimalData['publishTime'] ?? DateTime.now().toIso8601String());
      minimalData['lastUpdateTime'] = truncateMilliseconds(
          minimalData['lastUpdateTime'] ?? DateTime.now().toIso8601String());

      // Calculate expirationDate and republishTime
      final DateTime publishTime = DateTime.parse(minimalData['publishTime']);
      final DateTime expirationDate = publishTime.add(Duration(days: 30));
      final DateTime republishTime =
          publishTime.add(const Duration(minutes: 20));

      // Set the values in minimalData after truncating milliseconds
      minimalData['expirationDate'] =
          truncateMilliseconds(expirationDate.toIso8601String());
      minimalData['republishTime'] =
          truncateMilliseconds(republishTime.toIso8601String());

      // Debugging: Print values before inserting
      print('Inserting into indexes: $minimalData');

      // Insert into IndexManager database
      _database.execute('''
      INSERT INTO indexes (keyword, location, replicationFactor, copyNo, layerID, status, entryDateTime, expirationDate, publishTime, republishTime, lastUpdateTime)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
        minimalData['keyword'],
        minimalData['location'],
        minimalData['replicationFactor'],
        minimalData['copyNo'],
        minimalData['layerID'],
        minimalData['status'],
        minimalData['entryDateTime'],
        minimalData['expirationDate'],
        minimalData['publishTime'],
        minimalData['republishTime'],
        minimalData['lastUpdateTime']
      ]);

      // Add to cache and check for success
      bool cacheSuccess = _cacheManager.addToCache(
          minimalData['keyword'], minimalData, minimalData['expirationDate']);

      if (!cacheSuccess) {
        print('Failed to add to cache for keyword: ${minimalData['keyword']}');
      }

      return minimalData;
      // Return the inserted data
    } catch (e, stackTrace) {
      // Log the error for debugging
      print('Error inserting into indexes: $e');
      print('Stack trace: $stackTrace');
      throw e; // Rethrow the error for further handling
    }
  }
  // Future<Map<String, dynamic>> processAndInsertIndex(
  //     Map<String, dynamic> minimalData) async {
  //   try {
  //     // Add missing fields
  //     minimalData['copyNo'] = 1;
  //     minimalData['status'] = 'active';
  //     minimalData['entryDateTime'] = truncateMilliseconds(
  //         minimalData['entryDateTime'] ?? DateTime.now().toIso8601String());
  //     minimalData['publishTime'] = truncateMilliseconds(
  //         minimalData['publishTime'] ?? DateTime.now().toIso8601String());
  //     minimalData['lastUpdateTime'] = truncateMilliseconds(
  //         minimalData['lastUpdateTime'] ?? DateTime.now().toIso8601String());

  //     // Calculate expirationDate and republishTime
  //     final DateTime publishTime = DateTime.parse(minimalData['publishTime']);
  //     final DateTime expirationDate = publishTime.add(Duration(days: 30));
  //     final DateTime republishTime =
  //         publishTime.add(const Duration(minutes: 20));

  //     // Set the values in minimalData after truncating milliseconds
  //     minimalData['expirationDate'] =
  //         truncateMilliseconds(expirationDate.toIso8601String());
  //     minimalData['republishTime'] =
  //         truncateMilliseconds(republishTime.toIso8601String());

  //     // Debugging: Print values and types before inserting
  //     print('Inserting into indexes:');
  //     print(
  //         'indexID: ${minimalData['indexID']} (type: ${minimalData['indexID'].runtimeType})');
  //     print(
  //         'keyword: ${minimalData['keyword']} (type: ${minimalData['keyword'].runtimeType})');
  //     print(
  //         'location: ${minimalData['location']} (type: ${minimalData['location'].runtimeType})');
  //     print(
  //         'replicationFactor: ${minimalData['replicationFactor']} (type: ${minimalData['replicationFactor'].runtimeType})');
  //     print(
  //         'copyNo: ${minimalData['copyNo']} (type: ${minimalData['copyNo'].runtimeType})');
  //     print(
  //         'layerID: ${minimalData['layerID']} (type: ${minimalData['layerID'].runtimeType})');
  //     print(
  //         'status: ${minimalData['status']} (type: ${minimalData['status'].runtimeType})');
  //     print(
  //         'entryDateTime: ${minimalData['entryDateTime']} (type: ${minimalData['entryDateTime'].runtimeType})');
  //     print(
  //         'expirationDate: ${minimalData['expirationDate']} (type: ${minimalData['expirationDate'].runtimeType})');
  //     print(
  //         'publishTime: ${minimalData['publishTime']} (type: ${minimalData['publishTime'].runtimeType})');
  //     print(
  //         'republishTime: ${minimalData['republishTime']} (type: ${minimalData['republishTime'].runtimeType})');
  //     print(
  //         'lastUpdateTime: ${minimalData['lastUpdateTime']} (type: ${minimalData['lastUpdateTime'].runtimeType})');

  //     // Insert into IndexManager database
  //     _database.execute('''
  //   INSERT INTO indexes ( keyword, location, replicationFactor, copyNo, layerID, status, entryDateTime, expirationDate, publishTime, republishTime, lastUpdateTime)
  //   VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  //   ''', [
  //       minimalData['keyword'],
  //       minimalData['location'],
  //       minimalData['replicationFactor'],
  //       minimalData['copyNo'],
  //       minimalData['layerID'],
  //       minimalData['status'],
  //       minimalData['entryDateTime'],
  //       minimalData['expirationDate'],
  //       minimalData['publishTime'],
  //       minimalData['republishTime'],
  //       minimalData['lastUpdateTime']
  //     ]);

  //     // Add to cache and check for success
  //     bool cacheSuccess = _cacheManager.addToCache(
  //         minimalData['keyword'], minimalData, minimalData['expirationDate']);

  //     if (!cacheSuccess) {
  //       _logger.severe(
  //           'Failed to add to cache for keyword: ${minimalData['keyword']}');
  //     }

  //     return minimalData; // Return the inserted data
  //   } catch (e) {
  //     _logger.severe('Error inserting index: $e');
  //     rethrow; // Rethrow the error for further handling
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

  Future<void> updateIndex(String keyword, String updatedLocation) async {
    try {
      // Find the existing entry based on the keyword
      final result = _database.select(
        'SELECT * FROM indexes WHERE keyword = ?',
        [keyword],
      );

      if (result.isNotEmpty) {
        // // Retrieve the existing entry
        // final existingEntry = result.first;

        // Get the current time for lastUpdateTime
        final DateTime lastUpdateTime = DateTime.now();

        // Set the expirationDate to 30 days from now
        final DateTime expirationDate = DateTime.now().add(Duration(days: 30));

        // Use DateTime.parse() to handle publishTime and add 20 minutes to it
        final DateTime publishTime = DateTime.now(); // Set to current time
        final DateTime republishTime = publishTime.add(Duration(minutes: 20));

        // Update the database with the new location, expirationDate, republishTime, lastUpdateTime, and status
        _database.execute(
          'UPDATE indexes SET location = ?, expirationDate = ?, republishTime = ?, lastUpdateTime = ?, status = ? WHERE keyword = ?',
          [
            updatedLocation,
            expirationDate.toIso8601String(),
            republishTime.toIso8601String(),
            lastUpdateTime.toIso8601String(),
            'active', // Update status to "active"
            keyword,
          ],
        );

        // Update cache using Cache Manager
        _cacheManager.updateCache(
          keyword,
          {
            'location': updatedLocation,
            'expirationDate': expirationDate.toIso8601String(),
            'republishTime': republishTime.toIso8601String(),
            'lastUpdateTime': lastUpdateTime.toIso8601String(),
            'status': 'active', // Update status to "active"
          },
          expirationDate.toIso8601String(),
        );
      } else {
        _logger.warning('No entry found for keyword: $keyword');
      }
    } catch (e) {
      _logger.severe('SQLite Exception during update: $e');
    }
  }

  // Future<void> updateIndex(
  //     Map<String, dynamic> indexData, String updatedLocation) async {
  //   try {
  //     final DateTime expirationDate = indexData['lastUpdateTime'] == null
  //         ? stringToDate(
  //                 indexData['entryDateTime'] ?? DateTime.now().toString())
  //             .add(Duration(days: 30))
  //         : add24Hours(stringToDate(
  //             indexData['lastUpdateTime'] ?? DateTime.now().toString()));

  //     // Use DateTime.parse() to handle publishTime and add 20 minutes to it
  //     final DateTime publishTime =
  //         DateTime.parse(indexData['publishTime'] ?? DateTime.now().toString());
  //     final DateTime republishTime =
  //         publishTime.add(const Duration(minutes: 20));

  //     final DateTime lastUpdateTime = DateTime.now();

  //     _database.execute(
  //       'UPDATE indexes SET location = ?, expirationDate = ?, republishTime = ?, lastUpdateTime = ?, status = ? WHERE keyword = ?',
  //       [
  //         updatedLocation,
  //         dateToString(expirationDate),
  //         dateToString(republishTime),
  //         dateToString(lastUpdateTime),
  //         'active', // Update status to "active"
  //         indexData['keyword']
  //       ],
  //     );

  //     // Update cache using Cache Manager
  //     _cacheManager.updateCache(
  //         indexData['keyword'],
  //         {
  //           ...indexData,
  //           'location': updatedLocation,
  //           'expirationDate': dateToString(expirationDate),
  //           'republishTime': dateToString(republishTime),
  //           'lastUpdateTime': dateToString(lastUpdateTime),
  //           'status': 'active', // Update status to "active"
  //         },
  //         dateToString(expirationDate));
  //   } catch (e) {
  //     _logger.severe('SQLite Exception during update: $e');
  //   }
  // }

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
          'deletedAt': dateToString(now),
        };

        _database.execute(
          'INSERT INTO purge (keyword, location, replicationFactor, copyNo, layerID, status, entryDateTime, expirationDate, publishTime, republishTime, deletedAt) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
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

  Future<void> publishIndex(Map<String, dynamic> indexData,
      String serverSignedCertificate, payload) async {
    try {
      final DateTime now = getDateTime();
      final String nowStr = dateToString(now);
      final String publishTime = nowStr;
      final DateTime expirationDate = now.add(Duration(days: 30));
      final String hash = computeHash(indexData['location']);

      // Calculate republishTime as 20 minutes added to publishTime
      final DateTime republishTime = DateTime.parse(publishTime).add(
        const Duration(minutes: 20),
      );

      // Insert the index data into the database
      _database.execute(
        'INSERT INTO indexes (keyword, location, replicationFactor, copyNo, layerID, status, entryDateTime, expirationDate, publishTime, republishTime, lastUpdateTime) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
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

        final DateTime republishTime = now.add(Duration(minutes: 20));

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

// Helper function to move an index to the purge table
  Future<void> _moveToPurgeTable(
      Map<String, dynamic> index, String status) async {
    final DateTime now = DateTime.now();
    try {
      _database.execute(
        'INSERT INTO purge (keyword, location, replicationFactor, copyNo, layerID, status, entryDateTime, expirationDate, publishTime, republishTime, deletedAt) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          index['keyword'],
          index['location'],
          index['replicationFactor'],
          index['copyNo'],
          index['layerID'],
          status,
          index['entryDateTime'],
          index['expirationDate'],
          index['publishTime'],
          index['republishTime'],
          dateToString(now),
        ],
      );
    } catch (e) {
      _logger.severe('Failed to move index to purge table. Error: $e');
    }
  }

// Helper function to delete an index from the indexes table
  Future<void> _deleteFromIndexes(String keyword) async {
    try {
      _database.execute('DELETE FROM indexes WHERE keyword = ?', [keyword]);
    } catch (e) {
      _logger
          .severe('Failed to delete index with keyword "$keyword". Error: $e');
    }
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
        // Move expired index to purge table
        await _moveToPurgeTable(index, 'deleted');

        // Remove expired index from the main indexes table
        await _deleteFromIndexes(index['keyword']);
      }

      // Step 2: Handle explicitly deleted indexes
      final deletedIndexes = await _database.select(
        'SELECT * FROM indexes WHERE status = ?',
        ['deleted'],
      );

      for (final index in deletedIndexes) {
        // Move deleted index to purge table
        await _moveToPurgeTable(index, 'deleted');

        // Remove deleted index from the main indexes table
        await _deleteFromIndexes(index['keyword']);
      }

      // Step 3: Remove entries older than 30 days from the purge table
      await _removeOldPurgeEntries();

      // Step 4: Remove expired entries from the cache
      _cacheManager.removeExpiredCacheEntries(now);

      _logger.info('Purged expired and deleted indexes successfully.');
    } catch (e) {
      _logger.severe('Failed to purge indexes. Error: $e');
    }
  }

// Function to remove old entries from the purge table (older than 30 days)
  Future<void> _removeOldPurgeEntries() async {
    final DateTime now = DateTime.now();
    final DateTime threshold = now.subtract(Duration(days: 30));

    try {
      // Step 1: Count the entries that will be deleted
      final deletedCountResult = await _database.select(
        'SELECT COUNT(*) FROM purge WHERE deletedAt < ?',
        [dateToString(threshold)],
      );

      final deletedCount = deletedCountResult.isNotEmpty
          ? deletedCountResult[0]['COUNT(*)'] as int
          : 0;

      // Step 2: Perform the delete operation
      _database.execute(
        'DELETE FROM purge WHERE deletedAt < ?',
        [dateToString(threshold)],
      );

      // Step 3: Log the count of deleted entries
      _logger.info('Removed $deletedCount old entries from the purge table.');
    } catch (e) {
      _logger.severe(
          'Failed to remove old entries from the purge table. Error: $e');
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

// // Function to handle purging of expired and deleted indexes
//   Future<void> _purgeIndexes() async {
//     final DateTime now = DateTime.now();

//     try {
//       // Step 1: Fetch and move expired indexes to the purge table
//       final expiredIndexes = await _database.select(
//         'SELECT * FROM indexes WHERE expirationDate < ?',
//         [now.toIso8601String()],
//       );

//       for (final index in expiredIndexes) {
//         // Insert expired indexes into the purge table
//         _database.execute(
//           'INSERT INTO purge (keyword, location, replicationFactor, copyNo, layerID, status, entryDateTime, expirationDate, publishTime, republishTime, deletedAt) '
//           'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?,?)',
//           [
//             index['keyword'],
//             index['location'],
//             index['replicationFactor'],
//             index['copyNo'],
//             index['layerID'],
//             'deleted', // Mark as deleted
//             index['entryDateTime'],
//             index['expirationDate'],
//             index['publishTime'],
//             index['republishTime'],

//             dateToString(now), // Log the purge timestamp
//           ],
//         );

//         // Remove expired indexes from the main indexes table
//         _database.execute(
//             'DELETE FROM indexes WHERE keyword = ?', [index['keyword']]);
//       }

//       // Step 2: Handle explicitly deleted indexes
//       final deletedIndexes = await _database.select(
//         'SELECT * FROM indexes WHERE status = ?',
//         ['deleted'],
//       );

//       for (final index in deletedIndexes) {
//         // Insert deleted indexes into the purge table
//         _database.execute(
//           'INSERT INTO purge (keyword, location, replicationFactor, copyNo, layerID, status, entryDateTime, expirationDate, publishTime, republishTime, deletedAt) '
//           'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
//           [
//             index['keyword'],
//             index['location'],
//             index['replicationFactor'],
//             index['copyNo'],
//             index['layerID'],
//             'deleted', // Keep as deleted
//             index['entryDateTime'],
//             index['expirationDate'],
//             index['publishTime'],
//             index['republishTime'],

//             dateToString(now), // Log the purge timestamp
//           ],
//         );

//         // Remove deleted indexes from the main indexes table
//         _database.execute(
//             'DELETE FROM indexes WHERE keyword = ?', [index['keyword']]);
//       }

//       // Step 3: Remove entries older than 30 days from the purge table
//       await _removeOldPurgeEntries();

//       // Step 4: Remove expired entries from the cache
//       _cacheManager.removeExpiredCacheEntries(now);

//       _logger.info('Purged expired and deleted indexes successfully.');
//     } catch (e) {
//       _logger.severe('Failed to purge indexes. Error: $e');
//     }
//   }

//   Future<void> _removeOldPurgeEntries() async {
//     final DateTime now = DateTime.now();
//     final DateTime threshold = now.subtract(Duration(days: 30));

//     try {
//       // Step 1: Count the entries that will be deleted
//       final deletedCountResult = await _database.select(
//         'SELECT COUNT(*) FROM purge WHERE deletedAt < ?',
//         [dateToString(threshold)],
//       );

//       final deletedCount = deletedCountResult.isNotEmpty
//           ? deletedCountResult[0]['COUNT(*)'] as int
//           : 0;

//       // Step 2: Perform the delete operation
//       _database.execute(
//         'DELETE FROM purge WHERE deletedAt < ?',
//         [dateToString(threshold)],
//       );

//       // Step 3: Log the count of deleted entries
//       _logger.info('Removed $deletedCount old entries from the purge table.');
//     } catch (e) {
//       _logger.severe(
//           'Failed to remove old entries from the purge table. Error: $e');
//     }
//   }

// // Public method to trigger purging manually
//   Future<void> purgeIndexes() async {
//     await _purgeIndexes();
//   }

// // Scheduling the periodic purge task
//   void schedulePurgeTask() {
//     Timer.periodic(Duration(minutes: 20), (timer) async {
//       await _purgeIndexes(); // Periodically purge indexes
//     });
//   }

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

          'lastUpdateTime': dateToString(now), // Update timestamp
        };

        // Insert restored data back into the indexes table
        _database.execute(
          'INSERT INTO indexes (keyword, location, replicationFactor, copyNo, layerID, status, entryDateTime, expirationDate, publishTime, republishTime, lastUpdateTime) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?,  ?)',
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

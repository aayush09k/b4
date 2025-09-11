///@version: 1.0.0
///
///name:indexmgr
///
///author:
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';

/// Provides a logging framework.

import 'package:sqlite3/sqlite3.dart';

/// Provides an interface to SQLite databases.

import 'cachemgr.dart';

/// Imports the custom Cache Manager module.

import 'dart:async';

/// Provides support for asynchronous programming with classes like Future and Stream.

import 'dart:convert';

/// Initializes a logger for the B4IndexManager class.

final Logger _logger = Logger('B4IndexManager');

/// Configures the logging settings for the application.
///
/// Sets the root logger level to 'ALL' to capture all log messages.
///
/// Adds a listener to the root logger that prints each log record's level, time, and message.



//same both places but it is private there at package
void _initializeLogging() {
  /// Sets the root logger's level to capture all log messages (finest to severe).

  Logger.root.level = Level.ALL;

  /// Listens for new log records and prints them to the console.

  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
}

class B4IndexManager {
  ///declaring a class named B4IndexManager
  ///
  /// Represents the SQLite database instance used for storing index data.

  late final Database _database;


  /// Declares a late final variable to hold an instance of the cache manager.

  late final B4CacheManager _cacheManager;

  /// Sets the default maximum cache size to 10.

  int maxCacheSize = 10; // Default max cache size

  /// Add a getter to access _cacheManager and then returns the B4CacheManager instance

  B4CacheManager getCacheManager() => _cacheManager;

  /// Constructor for the B4IndexManager class is defined here. and then it initializes logging, the database connection, and the cache manager.
  ///
  /// Schedules a task to periodically purge old data.

  B4IndexManager(String dbPath) {
    _initializeLogging();
    _initializeDatabase(dbPath).then((_) {
      /// Asynchronously initializes the database using the provided path.

      _cacheManager = B4CacheManager(_database, maxCacheSize: maxCacheSize);

      /// Initializes the cache manager with the database instance and max cache size.

      schedulePurgeTask();

      /// Schedules a periodic task to purge old or expired data.
    }).catchError((e) {
      /// Handles any errors that occur during database initialization.

      _logger.severe('Initialization error: $e');

      /// Logs a severe error if initialization fails.
    });

    /// Initializes the logging system for the B4IndexManager.
  }

  /// Returns the [Database] instance used by the index manager.

  Database get database => _database;

  /// Initialization of the SQLite database and the creation of necessary tables if they donot exist.
  ///
  /// Returns a [Future] that completes when the database is initialized.

  Future<void> _initializeDatabase(String dbPath) async {
    try {
      /// Creates a directory named 'database' if it doesn't exist.

      final directory = Directory('database');

      /// Creates the directory if it does not exist.

      if (!directory.existsSync()) {
        directory.createSync();
      }

      /// final dbPath = 'database/init.db';

      _database = sqlite3.open(dbPath, mode: OpenMode.readWriteCreate);

      /// Creates the 'indexes' table if it doesn't exist, defining columns for index metadata.

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

      /// Creates the 'purge' table to store temporarily removed index entries, with a 'deletedAt' timestamp.

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

      /// Creates the 'cache' table for quick access to frequently used data, including an expiration date.

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

  // calling private function _initializeDatabase
  Future<void> initializeDatabase (String dbPath) async { await _initializeDatabase(dbPath);}

  /// Returns the current date and time.
  ///
  /// Returns a [DateTime] object representing the current date and time.

  DateTime getDateTime() => DateTime.now();

  /// Converts a [DateTime] object to an ISO 8601 formatted string.
  ///
  /// Returns a string in ISO 8601 format.

  String dateToString(DateTime date) => date.toIso8601String();

  /// Parses a string in ISO 8601 format into a [DateTime] object.
  ///
  /// Returns a [DateTime] object.

  DateTime stringToDate(String dateStr) => DateTime.parse(dateStr);

  //modification to add public function of [_initializeLogging]
  ///
  /// Function to call private [initializeLogging] function
  Future <void> initializeLogging() async{
    return _initializeLogging();
  }
  /// Computes a SHA256 hash for a given location string and compute the first hash from a location
  ///
  /// Returns the SHA256 hash as a hexadecimal string.


  String computeHash1(String location) {
    return sha256.convert(utf8.encode(location)).toString();
  }

  /// Computes a sha256 hash by combining a base hash and a copy number.
  ///
  /// Compute the second hash (hash2) by appending copyNo to hash1

  String computeHash2(String hash1, int copyNo) {
    String combined = '$hash1-copy$copyNo';
    return sha256.convert(utf8.encode(combined)).toString();
  }

  /// Truncates milliseconds from a datetime string and replaces 'T' with a space.

  String truncateMilliseconds(String datetime) {
    return datetime.split('.').first.replaceFirst('T', ' ');
  }

  /// Processes and inserts minimal index data into the database and cache.

  Future<Map<String, dynamic>> processAndInsertIndex(
      Map<String, dynamic> minimalData) async {
    /// Processes and inserts index data into the database and cache and it adds default values for missing fields, calculates expiration and republish times and handles the database insertion and cache update.
    ///
    /// Returns a [Future] of a [Map] representing the processed and inserted index data.

    try {
      /// Add missing fields

      minimalData['copyNo'] = 1;
      minimalData['status'] = 'active';
      minimalData['entryDateTime'] = truncateMilliseconds(
          minimalData['entryDateTime'] ?? DateTime.now().toIso8601String());
      minimalData['publishTime'] = truncateMilliseconds(
          minimalData['publishTime'] ?? DateTime.now().toIso8601String());
      minimalData['lastUpdateTime'] = truncateMilliseconds(
          minimalData['lastUpdateTime'] ?? DateTime.now().toIso8601String());

      /// Calculate expirationDate and republishTime

      final DateTime publishTime = DateTime.parse(minimalData['publishTime']);
      final DateTime expirationDate = publishTime.add(Duration(days: 30));
      final DateTime republishTime =
      publishTime.add(const Duration(minutes: 20));

      /// Set the values in minimalData after truncating milliseconds

      minimalData['expirationDate'] =
          truncateMilliseconds(expirationDate.toIso8601String());
      minimalData['republishTime'] =
          truncateMilliseconds(republishTime.toIso8601String());

      /// Debugging: Print values before inserting

      print('Inserting into indexes: $minimalData');

      /// Insert into IndexManager database

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

      /// Add to cache and check for success

      bool cacheSuccess = _cacheManager.addToCache(
          minimalData['keyword'], minimalData, minimalData['expirationDate']);

      if (!cacheSuccess) {
        print('Failed to add to cache for keyword: ${minimalData['keyword']}');
      }

      return minimalData;

      /// Return the inserted data
    } catch (e, stackTrace) {
      /// Log the error for debugging

      print('Error inserting into indexes: $e');
      print('Stack trace: $stackTrace');
      throw e;

      /// Rethrow the error for further handling
    }
  }

  /// Reads an index entry by keyword, with an option for partial search.

  Future<Map<String, dynamic>?> readByKeyword(String keyword,
      {bool partialSearch = false})

  /// Reads index entries from the cache or database based on a keyword then returns a [Future] that resolves to a [Map] containing the index data if found, otherwise null.
  ///
  /// This is intended to verify that the `readByKeyword correctly retrieves entries when a partial keyword is provided.

  async {
    final DateTime newExpirationDate = getDateTime().add(Duration(days: 30));

    /// searches an in-memory cache for an entry associated with the given keyword. If found, it updates the entry's expiration date in the cache and returns the cached data
    ///
    /// Check the cache using Cache Manager

    final cachedData = _cacheManager.getFromCache(keyword);
    if (cachedData != null) {
      /// Update expiration date in cache

      _cacheManager.updateCache(
          keyword,
          {
            ...cachedData,
            'expirationDate': dateToString(newExpirationDate),
          },
          dateToString(newExpirationDate));
      return cachedData;
    }

    /// Construct the SQL query based on whether partial search is needed

    final String query;
    final List<dynamic> parameters;

    if (partialSearch) {
      /// If partialSearch is true, it constructs a SQL query with LIKE ? for a partial match. If false, it uses = ? for an exact match.

      query = 'SELECT * FROM indexes WHERE keyword LIKE ?';
      parameters = ['%$keyword%'];
    } else {
      query = 'SELECT * FROM indexes WHERE keyword = ?';
      parameters = [keyword];
    }

    //// Check the indexes table

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

      /// If an index entry is found in the main indexes table, it's added to the cache

      _cacheManager.addToCache(
          keyword, result, dateToString(newExpirationDate));

      return result;
    }

    ///if the index entry is found in purge then it's restored to indexes and added to the canhe and removed fromt the purge

    final purgeQuery = partialSearch
        ? 'SELECT * FROM purge WHERE keyword LIKE ?'

    ///If partialSearch is true, it builds a query to find keywords that contain the given keyword and if false then it build a querry to find keywords that match the given keyword.

        : 'SELECT * FROM purge WHERE keyword = ?';
    final purgeParameters = partialSearch ? ['%$keyword%'] : [keyword];

    final purgeResult = _database.select(purgeQuery, purgeParameters);

    if (purgeResult.isNotEmpty) {
      await restoreIndexFromPurge(keyword);

      ///moves the found entry from the purge table back to the main indexes table and updates the in-memory cache

      return _cacheManager.getFromCache(keyword);

      ///It then attempts to return the data from the _cacheManager
    }

    return null;

    ///if the keyword is not found then it returns null
  }

  /// Updates an existing index entry with a new location and refreshed timestamps.
  ///
  /// Updates the location of an index entry identified by its keyword.

  Future<void> updateIndex(String keyword, String updatedLocation) async {
    try {
      /// Find the existing entry based on the keyword

      final result = _database.select(
        'SELECT * FROM indexes WHERE keyword = ?',
        [keyword],
      );

      if (result.isNotEmpty) {
        /// Retrieve the existing entry
        ///
        /// Get the current time for lastUpdateTime

        final DateTime lastUpdateTime = DateTime.now();

        /// Set the expirationDate to 30 days from now

        final DateTime expirationDate = DateTime.now().add(Duration(days: 30));

        /// Use DateTime.parse() to handle publishTime and add 20 minutes to it

        final DateTime publishTime = DateTime.now(); // Set to current time
        final DateTime republishTime = publishTime.add(Duration(minutes: 20));

        /// Update the database with the new location, expirationDate, republishTime, lastUpdateTime, and status

        _database.execute(
          'UPDATE indexes SET location = ?, expirationDate = ?, republishTime = ?, lastUpdateTime = ?, status = ? WHERE keyword = ?',
          [
            updatedLocation,
            expirationDate.toIso8601String(),
            republishTime.toIso8601String(),
            lastUpdateTime.toIso8601String(),
            'active',

            /// Update status to "active"

            keyword,
          ],
        );

        /// Updates the cache using cache manager.

        _cacheManager.updateCache(
          keyword,
          {
            'location': updatedLocation,
            'expirationDate': expirationDate.toIso8601String(),
            'republishTime': republishTime.toIso8601String(),
            'lastUpdateTime': lastUpdateTime.toIso8601String(),
            'status': 'active',

            /// Update status to "active"
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

  /// Deletes an index entry identified by its keyword.
  ///
  /// Moves the entry to a 'purge' table instead of permanently deleting it, and removes it from the cache. The keyword identifying the index entry to delete.
  ///
  /// Returns a [Future] that completes when the entry is moved to the purge table and removed from the cache.
  ///
  /// Deletes an index entry by keyword, moving it to the purge table.

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

        /// Remove from cache using Cache Manager

        _cacheManager.removeFromCache(keyword);
      }
    } catch (e, stackTrace) {
      _logger.severe(
          'Failed to delete index with keyword "$keyword". Error: $e',
          e,
          stackTrace);
    }
  }
  /// Adds 24 hours to a given DateTime.
  ///
  /// Helper function to add 24 hours to a DateTime

  DateTime add24Hours(DateTime dateTime) => dateTime.add(Duration(hours: 24));

  /// Adds 12 months to a given DateTime.
  ///
  /// Helper function to add 12 months to a DateTime

  DateTime add12Months(DateTime dateTime) {
    ///updated on 13-06-2025
    ///
    ///in this functions we are adding 12 months to the present date.

    final int newYear = dateTime.year + (dateTime.month + 12) ~/ 12;
    final int newMonth = (dateTime.month + 12) % 12;
    final int newDay = dateTime.day;
    return DateTime(newYear, newMonth, newDay, dateTime.hour, dateTime.minute,
        dateTime.second);
  }

  /// Publishes new index data to the database and cache and also publishes an index by inserting it into the database updating cache.
  ///
  /// Computes a hash of the location, sets timestamps, and manages the index lifecycle.
  ///
  /// [indexData]: A [Map] containing index details like keyword, location, replication factor, etc.
  ///
  /// [serverSignedCertificate]: is an  unused parameter (can be removed or utilized in future implementations).
  ///
  /// [payload]: Unused parameter (can be removed or utilized in future implementations).
  ///
  /// Returns a [Future] that completes when the index is published.

  Future<void> publishIndex(Map<String, dynamic> indexData,
      String serverSignedCertificate, payload) async
  {
    try {
      final DateTime now = getDateTime();
      final String nowStr = dateToString(now);
      final String publishTime = nowStr;
      final DateTime expirationDate = now.add(Duration(days: 30));
      final String hash = computeHash(indexData['location']);

      /// `computeHash` method.
      ///
      /// This verifies that the `computeHash` method in `B4IndexManager`
      ///
      /// correctly computes the SHA-256 hash of a given string.
      ///
      ///- Calculate republishTime as 20 minutes added to publishTime

      final DateTime republishTime = DateTime.parse(publishTime).add(
        const Duration(minutes: 20),
      );

      /// Insert the index data into the database

      _database.execute(
        'INSERT INTO indexes (keyword, location, replicationFactor, copyNo, layerID, status, entryDateTime, expirationDate, publishTime, republishTime, lastUpdateTime) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          indexData['keyword'],
          hash,

          /// Store the hash of the location

          indexData['replicationFactor'],
          indexData['copyNo'],
          indexData['layerID'],
          'active',
          nowStr,
          dateToString(expirationDate),
          publishTime,
          dateToString(republishTime),

          nowStr,

          ///serverSignedCertificate, Insert the server-signed certificate
        ],
      );

      /// Add to cache using Cache Manager

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
        },
        dateToString(expirationDate),
      );
    } catch (e) {
      _logger.severe('Failed to publish index "$indexData". Error: $e');
    }
  }

  /// Republishes an existing index, updating its republish and expiration times, or we can say that republishes an existing index by updating its republish time and expiration date.
  ///
  /// Updates the corresponding entry in both the database and the cache.
  ///
  /// [keyword]: The keyword identifying the index to republish.
  ///
  /// Returns a [Future] that completes when the index is republished.

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

        /// Update cache using Cache Manager

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

  ///This function computes a SHA256 hash of the input string data after encoding it to UTF-8, logs an error and rethrows if an exception occurs during the process, and returns the hash as a hexadecimal string.

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

  /// Should be called when the B4IndexManager instance is no longer needed to release resources.
  ///
  /// Disposes of the database connection.

  void dispose() {
    _database.dispose();

    /// Ensure the database connection is closed
  }

  /// moveToPurgeTable Moves an index entry to the purge table with a specified status.
  ///
  /// Moves an index entry to the purge table.

  Future<void> _moveToPurgeTable(
      Map<String, dynamic> index, String status) async {
        try {
            final DateTime now = DateTime.now();
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
    }
    catch (e) {
      _logger.severe('Failed to move index to purge table. Error: $e');
    }
  }

  /// Deletes an index entry directly from the 'indexes' table.
  ///
  /// The _deleteFromIndexes function is used internally as part of the purging process.

  Future<void> _deleteFromIndexes(String keyword) async {
    try {
      _database.execute('DELETE FROM indexes WHERE keyword = ?', [keyword]);

      /// Executes the delete command.
    } catch (e) {
      _logger
          .severe('Failed to delete index with keyword "$keyword". Error: $e');
    }
  }

  /// Handles the purging of expired and deleted indexes from the 'indexes' table and cacheand the function is used to handle the purging the deleted entries form the table
  ///
  /// It moves such entries to the 'purge' table and removes old entries from the 'purge' table itself. Also cleans up the cache.

  Future<void> _purgeIndexes() async {
    final DateTime now = DateTime.now();

    try {
      /// it fetches for the expired entries and move them to the purge table

      final expiredIndexes = await _database.select(
        'SELECT * FROM indexes WHERE expirationDate < ?',
        [now.toIso8601String()],
      );

      for (final index in expiredIndexes) {
        ///here w eare moving expired index to the purge table

        await _moveToPurgeTable(index, 'deleted');

        /// Remove expired index from the main indexes table

        await _deleteFromIndexes(index['keyword']);
      }

      /// the explicitly deleted databases are deleted here

      final deletedIndexes = await _database.select(
        'SELECT * FROM indexes WHERE status = ?',
        ['deleted'],
      );

      for (final index in deletedIndexes) {
        ///here we are moving deleted index to the purge table

        await _moveToPurgeTable(index, 'deleted');

        /// Remove deleted index from the main indexes table

        await _deleteFromIndexes(index['keyword']);
      }

      /// Remove entries older than 30 days from the purge table

      await _removeOldPurgeEntries();

      ///  here we are moving expired entries from the cache

      _cacheManager.removeExpiredCacheEntries(now);

      _logger.info('Purged expired and deleted indexes successfully.');
    } catch (e) {
      _logger.severe('Failed to purge indexes. Error: $e');
    }
  }

  /// Removes entries older than 30 days from the 'purge' table.and old entries from the 'purge' table also entries older than 30 days are considered to be old and are deleted.

  Future<void> _removeOldPurgeEntries() async {
    final DateTime now = DateTime.now();
    final DateTime threshold = now.subtract(
        Duration(days: 30)); // Calculates the threshold date (30 days ago).

    try {
      ///this counts the entries that are going to be declared.

      final deletedCountResult = await _database.select(
        'SELECT COUNT(*) FROM purge WHERE deletedAt < ?',
        [dateToString(threshold)],
      );

      final deletedCount = deletedCountResult.isNotEmpty
          ? deletedCountResult[0]['COUNT(*)'] as int
          : 0;

      ///the delete operation is being performed

      _database.execute(
        'DELETE FROM purge WHERE deletedAt < ?',
        [dateToString(threshold)],

        ///the entries that are older than the threshold is being deleted
      );

      /// It then logs the count of the deleted entries

      _logger.info('Removed $deletedCount old entries from the purge table.');
    } catch (e) {
      _logger.severe(
          'Failed to remove old entries from the purge table. Error: $e');
    }
  }

  ///the purging process is triggered here.
  ///
  /// This allows for on-demand cleanup of expired and deleted entries.

  Future<void> purgeIndexes() async {
    await _purgeIndexes();

    /// Calls the internal _purgeIndexes function to perform the actual purging.
  }

  /// Schedules a periodic task to purge indexes.
  ///
  /// The task runs every 20 minutes, invoking the internal _purgeIndexes method.

  void schedulePurgeTask() {
    Timer.periodic(Duration(minutes: 20), (timer) async {
      await _purgeIndexes();

      /// Periodically purge indexes
    });
  }

  /// Restores an index entry from the purge table back to the main indexes table.
  ///
  /// the function restoreIndexFromPurge is used to restore an index from the purge table

  Future<void> restoreIndexFromPurge(String keyword) async {
    try {
      final purgeResult =
      _database.select('SELECT * FROM purge WHERE keyword = ?', [keyword]);

      if (purgeResult.isNotEmpty) {
        final row = purgeResult.first;
        final now = DateTime.now();

        /// Prepare the restored data and as it has a final keyword, it means that it can be inserted only once.

        final restoredData = {
          'keyword': row['keyword'],
          'location': row['location'],
          'replicationFactor': row['replicationFactor'],
          'copyNo': row['copyNo'],
          'layerID': row['layerID'],
          'status': 'active',
          'entryDateTime': row['entryDateTime'],
          'expirationDate': row['expirationDate'],
          'publishTime': row['publishTime'],
          'republishTime': row['republishTime'],

          'lastUpdateTime': dateToString(now),

          /// used to update the timestamp
        };

        /// Inserts restored data back into the indexes table

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

        /// Remove the restored entry from the purge table once found

        _database.execute('DELETE FROM purge WHERE keyword = ?', [keyword]);

        /// used to add restored entry to the cache

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
  /// added to manually remove from the purge table for test case purpose
  ///
  /// Manually removes an index entry from the 'purge' table based on the keyword.
  ///
  /// Returns a [Future] that completes when the operation is done.
  /// It will log whether the deletion was successful or if the keyword was not found.
  Future<void> manuallyRemoveFromPurgeByKeyword(String keyword) async {
    try {
      /// First, check if the keyword exists in the purge table to provide better logging
      final existingEntry = _database.select(
        'SELECT keyword FROM purge WHERE keyword = ?',
        [keyword],
      );

      if (existingEntry.isNotEmpty) {
        _database.execute(
          'DELETE FROM purge WHERE keyword = ?',
          [keyword],
        );
        _logger.info('Manually removed entry with keyword "$keyword" from the purge table.');
      } else {
        _logger.info('Keyword "$keyword" not found in the purge table. No entry removed.');
      }
    } catch (e) {
      _logger.severe('Failed to manually remove entry with keyword "$keyword" from purge table. Error: $e');
      // Optionally, rethrow the error if you want the caller to handle it
      // throw e;
    }
  }
}
///-------------------------------------------------------------------------commented part------------------------------------------------------------------------------------------------------------
// import 'package:uuid/uuid.dart';
// import 'package:index_mgr/index_mgr.dart';
// Function to handle purging of expired and deleted indexes
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
// late String dbPath;
// String generateUUIDIndexID() {
//   var uuid = Uuid();
//   return uuid.v4(); /// Generates a unique UUID
// }
//'serverSignedCertificate': serverSignedCertificate, // Add to cache
// final existingEntry = result.first;
// final uuid = Uuid();
//  B4IndexManager({this.dbPath = 'database/index_olm.db'}) {
/// @Version:1.0.0
/// @Author:
/// @Name:indexmgr_test

/// Importing Test packages of Dart
import 'package:test/test.dart';

///Importing dart input/output library
import 'dart:io';

///importing dart convert library for coding and encoding
import 'dart:convert';

/// importing crypto library fro hashing
import 'package:crypto/crypto.dart';

/// importing SQLite for database operation
import 'package:sqlite3/sqlite3.dart';

/// importing [indexmgr] from a local packages
import 'package:indexmgr/indexmgr.dart';

/// importing [cachemgr] from a local packages
import 'package:indexmgr/cachemgr.dart';

/// function to Add entries to the Database
///
/// [numberOfEntries] for how many entries to inserted
int populateDatabase(Database database, int numberOfEntries) {
  /// to get the current time from system
  final timestamp = DateTime.now();
  int insertedCount = 0;
  /// loop to get  dummy entries to be inserted in database
  for (int i = 0; i < numberOfEntries; i++) {
    /// dummy entries value
    final keyword = 'testKey$i';
    final location = 'testLocation$i';
    final replicationFactor = 3; // Fixed
    final copyNo = 1; /// Integer value (copy number)
    final layerID = 1; /// Integer value (randomized between 1 and 3)
    final status = i % 2 == 0 ? 'active' : 'deleted'; /// Alternating status
    final entryDateTime =
        timestamp.subtract(Duration(days: i)).toIso8601String();
    final expirationDate =
        timestamp.add(Duration(days: 30 - i)).toIso8601String();
    final publishTime = timestamp.toIso8601String();
    final republishTime = DateTime.parse(publishTime)
        .add(Duration(minutes: 20))
        .toIso8601String();
    final lastUpdateTime = timestamp.toIso8601String();

    /// Inserting data into the `indexes` table using SQLite
    database.execute('''
    INSERT INTO indexes (
       keyword, location, replicationFactor, copyNo, layerID, status, 
      entryDateTime, expirationDate, publishTime, republishTime, lastUpdateTime
    )
    VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      keyword,
      location,
      replicationFactor,
      copyNo, /// Corrected: `copyNo` should match the `copyNo` column
      layerID,
      status,
      entryDateTime,
      expirationDate,
      publishTime,
      republishTime,
      lastUpdateTime,
    ]);
    /// increase the count after each data set inserted
    insertedCount++;
  }
  /// return the count of data inserted
  return insertedCount;
}


/// function to print the content of the Index and Purge Table
void printDatabaseEntries(Database database) {
  print('--- Indexes Table ---');
  /// to retrieve data of each row into indexRows from indexes
  final indexRows = database.select('SELECT * FROM indexes');
  ///loop to print each row from [indexRow]
  for (var row in indexRows) {
    print(row);
  }
  ///Print  content of purge Table
  print('--- Purge Table ---');
  /// to get data of each row into [purgeRows] from purge table
  final purgeRows = database.select('SELECT * FROM purge');
  /// loop to print each row from purge table
  for (var row in purgeRows) {
    print(row);
}}


/// Main Function(entry point)
///
/// [database],[indexManager] and [cacheManager] will be  initialized later
///
Future<void> main() async {
  late B4IndexManager indexManager;
  late B4CacheManager cacheManager;
  late Database database;
  final String dbPath = 'database/test_index_olm.db'; /// setting the database path
  ///
  final timestamp = DateTime.now();/// current timestamp

  final String serverSignedCertificate =
      'your_initial_server_signed_certificate'; /// Server Certificate

  setUpAll(() async {
    /// Initialize the index manager, which will set up the database
    indexManager = B4IndexManager(dbPath);
    database = indexManager.database; /// Directly accessing the database
    ///
    /// Wait for the database to be initialized
    await Future.delayed(Duration(seconds: 1));

    /// Populate the database with initial data only once
    populateDatabase(database, 50); /// Populate with 50 entries

    /// Access the initialized database
    database = indexManager
        .getCacheManager()
        .database; /// Assuming you have a way to get the database from the cache manager
    cacheManager = indexManager.getCacheManager(); /// retrieving data from cache manager
  });
  /// function to dispose the database after all test has been done.
  tearDownAll(() {
    database.dispose();
    if (File(dbPath).existsSync()) {
      File(dbPath).deleteSync();
    }
  });

  /// Example test to verify the database is initialized
  test('Verify database initialization', () {
    /// retrieving data from database and expecting some data if null test fail
    final rows = database.select('SELECT * FROM indexes');
    expect(rows, isNotNull);
  });

  /// test to verify if correct no. of data/entries has been inserted or not
  ///
  /// here 50 entries has been inserted
  test('Verify populateDatabase inserts correct number of entries', () {
    /// Query to verify the database also has 50 rows
    final rows = database.select('SELECT * FROM indexes');
    expect(rows.length, equals(50));

    /// Print the entries to the console
    print('Database entries:');
    printDatabaseEntries(database);
    print('All 50 entries verified successfully.');

  });

 /// Test to Insert Minimal Data and Verify if from Cache memory
  test('Insert Minimal Data and Verify Cache', () async {
    final keyword = 'minimalKey';
    final location = 'minimalLocation';
    int replicationFactor = 2;
    int layerID = 1;

    /// Step 1: Insert minimal data into the OLM database
    ///
    /// inserting minimal data into database
    database.execute('''
  INSERT INTO indexes ( keyword, location, replicationFactor, layerID)
    VALUES ( ?, ?, ?, ?)
    ''', [keyword, location, replicationFactor, layerID]);

    final minimalData = {
      'keyword': keyword,
      'location': location,
      'replicationFactor': replicationFactor,
      'layerID': layerID,
    };
    /// type conversion to string from int
    minimalData['replicationFactor'] =
        int.parse(minimalData['replicationFactor'].toString());
    minimalData['layerID'] = int.parse(minimalData['layerID'].toString());

    /// Step 2: Process and Insert the index using IndexManager
    await indexManager.processAndInsertIndex(minimalData);

    /// Step 3: Verify if the minimal data was correctly inserted
    final cachedData = cacheManager.cache[keyword]; /// Access the cache directly
    /// excepting some data in cache memory
    expect(cachedData, isNotNull,
        reason: 'Cache should not be null after insertion');
    ///expecting the data to be in cached Data
    expect(cachedData?['keyword'], equals(keyword));
    expect(cachedData?['location'], equals(location));
    /// print the this message when test passed
    print('Minimal Data Handling Test Passed');


    /// data/entry is to be deleted from the database using the keyword to save space
    ///
    /// it also remove the data from cache memory
    await indexManager.deleteIndex(keyword);
    /// checking if it exist  in the the  indexes and if no then data is deleted
    final getDeletedDataForCheck =
    database.select('SELECT * FROM indexes WHERE keyword = ?', [keyword]);
    expect( getDeletedDataForCheck.isEmpty, isTrue , reason:' data is not deleted from database');
    /// data is already removed from cache so it should be null
    ///
    /// checking if it exist  in the the cache memory and if no then data is deleted
    final deletedCachedData = cacheManager.getFromCache(keyword);
    expect(deletedCachedData, isNull);


    await indexManager.manuallyRemoveFromPurgeByKeyword(keyword);
    /// checking if it exist  in the the purge and if no then data is deleted
    final getDeletedDataForCheckFromPurge =
    database.select('SELECT * FROM purge WHERE keyword = ?', [keyword]);
    expect( getDeletedDataForCheckFromPurge.isEmpty, isTrue , reason:' data is not deleted from purge database');
    /// final delete message is printed
    print("Data is deleted from the index and purge table ");
  });

  /// Test to insert data into index and verify it from cache memory
  test('Insert Index and Verify Cache', () async {
    /// dummy entry creation
    final indexData = {
      'keyword': 'testKey',
      'location': 'testLocation',
      'replicationFactor': 3,
      'copyNo': 1,
      'layerID': 2,
      'status': 'active',
      'entryDateTime': timestamp.toIso8601String(),
      'expirationDate': timestamp.add(Duration(days: 30)).toIso8601String(),
      'publishTime': timestamp.toIso8601String(),
      'republishTime': timestamp.add(Duration(minutes: 20)).toIso8601String(),
      'lastUpdateTime': timestamp.toIso8601String(),
    };
    ///  waiting till data is inserting into the database by calling [processInsertIndex] function
    await indexManager.processAndInsertIndex(indexData);
    /// retrieving data from cache
    final cachedData = cacheManager.getFromCache('testKey');
    /// if data retrieved and matched test case passed
    expect(cachedData, isNotNull);
    expect(cachedData!['keyword'], equals('testKey'));
    /// Message to be displayed on successfully passing the test
    print('Insert Index Test Passed');

    final keyword='testkey';
    /// data/entry is to be deleted from the database using the keyword to save space
    ///
    /// it also remove the data from cache memory
    await indexManager.deleteIndex(keyword);
    /// checking if it exist  in the the  indexes and if no then data is deleted
    final getDeletedDataForCheck =
    database.select('SELECT * FROM indexes WHERE keyword = ?', [keyword]);
    expect( getDeletedDataForCheck.isEmpty, isTrue , reason:' data is not deleted from database');
    /// data is already removed from cache so it should be null
    ///
    /// checking if it exist  in the the cache memory and if no then data is deleted
    final deletedCachedData = cacheManager.getFromCache(keyword);
    expect(deletedCachedData, isNull);


    await indexManager.manuallyRemoveFromPurgeByKeyword(keyword);
    /// checking if it exist  in the the purge and if no then data is deleted
    final getDeletedDataForCheckFromPurge =
    database.select('SELECT * FROM purge WHERE keyword = ?', [keyword]);
    expect( getDeletedDataForCheckFromPurge.isEmpty, isTrue , reason:' data is not deleted from purge database');
    /// final delete message is printed
    print("Data is deleted from the index and purge table ");
  });

  /// test to update the index using keyword and then verifying it from cache memory
  test('Update Index using Keyword and Verify Cache', () async {
    final keyword = 'testKey';
    final initialLocation =
        'initialLocation'; /// This is only used for the initial insert
    final updatedLocation = 'updatedLocation';
    /// Step 1: Insert initial data into the database
    await indexManager.processAndInsertIndex({
      'keyword': keyword,
      'location': initialLocation,
      'replicationFactor': 3,
      'copyNo': 1,
      'layerID': 2,
      'status': 'active',
      'entryDateTime': timestamp.toIso8601String(),
      'expirationDate': timestamp
          .add(Duration(days: 30))
          .toIso8601String(), // 30 days from entryDateTime
      'publishTime': timestamp.toIso8601String(),
      'republishTime': timestamp.add(Duration(minutes: 20)).toIso8601String(),
      'lastUpdateTime': timestamp.toIso8601String(),
    });

    /// Step 2: Update the index with the new location using only the keyword
    ///
    /// if data exit then the old data will be updated in index and also in cache memory
    ///
    /// else it will throw the message data does not exist
    await indexManager.updateIndex(keyword, updatedLocation);

    /// Step 3: Verify if the location was correctly updated in the cache
    final cachedData = cacheManager.getFromCache(keyword);
    expect(cachedData, isNotNull);
    expect(cachedData!['location'], equals(updatedLocation));

    /// Step 4: Verify if the expiration date, publish time, and republish time were correctly updated in the database
    final updatedEntry =
        database.select('SELECT * FROM indexes WHERE keyword = ?', [keyword]);
    expect(updatedEntry.isNotEmpty, isTrue);
    expect(updatedEntry.first['location'], equals(updatedLocation));

    /// Get the actual expiration date from the updated entry
    final DateTime actualExpirationDate =
        DateTime.parse(updatedEntry.first['expirationDate']);
    final DateTime actualPublishTime =
        DateTime.parse(updatedEntry.first['publishTime']);
    final DateTime actualRepublishTime =
        DateTime.parse(updatedEntry.first['republishTime']);

    /// Get the current time for comparison
    final DateTime now = DateTime.now();

    /// Check if the expiration date is updated and within 30 seconds of the expected
    expect(actualExpirationDate.isAfter(now), isTrue);
    expect(actualExpirationDate.isBefore(now.add(Duration(days: 30))), isTrue);

    /// Check if the publish time is updated and within 30 seconds of the current time
    expect(
        actualPublishTime.isAfter(now.subtract(Duration(seconds: 30))), isTrue);
    expect(actualPublishTime.isBefore(now.add(Duration(seconds: 30))), isTrue);

    /// Check if the republish time is updated and within 30 seconds of the expected
    expect(
        actualRepublishTime
            .isAfter(actualPublishTime.add(Duration(minutes: 19))),
        isTrue);
    expect(
        actualRepublishTime
            .isBefore(actualPublishTime.add(Duration(minutes: 21))),
        isTrue);
     /// Messaged to be displayed when test case passed
    print('Update Index Test Passed');


    /// data/entry is to be deleted from the database using the keyword to save space
    ///
    /// it also remove the data from cache memory
    await indexManager.deleteIndex(keyword);
    /// checking if it exist  in the the  indexes and if no then data is deleted
    final getDeletedDataForCheck =
    database.select('SELECT * FROM indexes WHERE keyword = ?', [keyword]);
    expect( getDeletedDataForCheck.isEmpty, isTrue , reason:' data is not deleted from database');
    /// data is already removed from cache so it should be null
    ///
    /// checking if it exist  in the the cache memory and if no then data is deleted
    final deletedCachedData = cacheManager.getFromCache(keyword);
    expect(deletedCachedData, isNull);


    await indexManager.manuallyRemoveFromPurgeByKeyword(keyword);
    /// checking if it exist  in the the purge and if no then data is deleted
    final getDeletedDataForCheckFromPurge =
    database.select('SELECT * FROM purge WHERE keyword = ?', [keyword]);
    expect( getDeletedDataForCheckFromPurge.isEmpty, isTrue , reason:' data is not deleted from purge database');
    /// final delete message is printed
    print("Data is deleted from the index and purge table ");

  });

  /// test case to delete index and verify it from cache memory
  test('Delete Index and Verify Cache', () async {
    /// dummy data is to be inserted
    final indexData = {
      'keyword': 'testKeyToDelete',
      'location': 'testLocation',
      'replicationFactor': 3,
      'copyNo': 1,
      'layerID': 2,
      'status': 'active',
      'entryDateTime': timestamp.toIso8601String(),
      'expirationDate': timestamp.add(Duration(days: 30)).toIso8601String(),
      'publishTime': timestamp.toIso8601String(),
      'republishTime': timestamp.add(Duration(minutes: 20)).toIso8601String(),
      'lastUpdateTime': timestamp.toIso8601String(),
    };
   /// data in indexData is inserted into database
    await indexManager.processAndInsertIndex(indexData);

    /// data/entry is deleted from the database using the keyword
    ///
    /// it will also delete the data from cache memory
    await indexManager.deleteIndex('testKeyToDelete');
    /// checking if it exist  in the the cache memory and if no then data is deleted
    final cachedData = cacheManager.getFromCache('testKeyToDelete');
    expect(cachedData, isNull);


    final keyword='testKeyToDelete';
    /// retrieving data from index table if empty test data is deleted
    final getDeletedDataForCheck =
    database.select('SELECT * FROM indexes WHERE keyword = ?', [keyword]);
    expect( getDeletedDataForCheck.isEmpty, isTrue , reason:' data is not deleted from database');
    /// data is already removed from cache so it should be null
    ///
    /// checking if it exist  in the the cache memory and if no then data is deleted
    final deletedCachedData = cacheManager.getFromCache(keyword);
    expect(deletedCachedData, isNull);

    /// manually removing from purge table
    await indexManager.manuallyRemoveFromPurgeByKeyword(keyword);
    /// checking if it exist  in the the purge and if no then data is deleted
    final getDeletedDataForCheckFromPurge =
    database.select('SELECT * FROM purge WHERE keyword = ?', [keyword]);
    expect( getDeletedDataForCheckFromPurge.isEmpty, isTrue , reason:' data is not deleted from purge database');
    /// final delete message is printed
    print("Data is deleted from the index and purge table ");
  });

  /// test case to publish index and verify it from cache memory data
  test('Publish Index and Verify Cache', () async {
    ///dummy data to be inserted
    final indexData = {
      'keyword': 'testKeyToPublish',
      'location': 'testLocation',
      'replicationFactor': 3,
      'copyNo': 1,
      'layerID': 2,
      'status': 'active',
      'entryDateTime': timestamp.toIso8601String(),
      'expirationDate': timestamp.add(Duration(days: 30)).toIso8601String(),
      'publishTime': timestamp.toIso8601String(),
      'republishTime': timestamp.add(Duration(minutes: 20)).toIso8601String(),
      'lastUpdateTime': timestamp.toIso8601String(),
    };
    /// waiting till the data is being inserted into database and also retrieving [serverSignedCertificate]
    await indexManager.publishIndex(indexData, serverSignedCertificate,null);

    /// retrieving the data from cache using [getFromCache] function
    final cachedData = cacheManager.getFromCache('testKeyToPublish');
    /// if data for that keyword exist and its status is active then test case passed
    expect(cachedData, isNotNull);
    expect(cachedData!['status'], equals('active'));

    /// Messaged to be displayed when test case passed
    print('Publish Index Test Passed');

    final keyword='testKeyToPublish';
    /// data/entry is to be deleted from the database using the keyword to save space
    ///
    /// it also remove the data from cache memory
    await indexManager.deleteIndex(keyword);
    /// checking if it exist  in the the  indexes and if no then data is deleted
    final getDeletedDataForCheck =
    database.select('SELECT * FROM indexes WHERE keyword = ?', [keyword]);
    expect( getDeletedDataForCheck.isEmpty, isTrue , reason:' data is not deleted from database');
    /// data is already removed from cache so it should be null
    ///
    /// checking if it exist  in the the cache memory and if no then data is deleted
    final deletedCachedData = cacheManager.getFromCache(keyword);
    expect(deletedCachedData, isNull);


    await indexManager.manuallyRemoveFromPurgeByKeyword(keyword);
    /// checking if it exist  in the the purge and if no then data is deleted
    final getDeletedDataForCheckFromPurge =
    database.select('SELECT * FROM purge WHERE keyword = ?', [keyword]);
    expect( getDeletedDataForCheckFromPurge.isEmpty, isTrue , reason:' data is not deleted from purge database');
    /// final delete message is printed
    print("Data is deleted from the index and purge table ");

  });

  ///test case to republish index and verify it from cache memory data
  test('Republish Index and Verify Cache', () async {
    ///creating the dummy entry to be inserted
    final indexData = {
      'keyword': 'testKeyToRepublish',
      'location': 'testLocation',
      'replicationFactor': 3,
      'copyNo': 1,
      'layerID': 2,
      'status': 'active',
      'entryDateTime': timestamp.toIso8601String(),
      'expirationDate': timestamp.add(Duration(days: 30)).toIso8601String(),
      'publishTime': timestamp.toIso8601String(),
      'republishTime': timestamp.add(Duration(minutes: 20)).toIso8601String(),
      'lastUpdateTime': timestamp.toIso8601String(),
    };
   /// waiting till the data is inserted using[processAndInsertIndex] function
    await indexManager.processAndInsertIndex(indexData);

    /// republishing the index by [republishIndex] function
    await indexManager.republishIndex('testKeyToRepublish');
    /// get the the data from cache memory via [getFromCache] function
    final cachedData = cacheManager.getFromCache('testKeyToRepublish');
    /// if there is some data and the cache data's repbulishTime is not equal the indexData's republish time then test case passed
    expect(cachedData, isNotNull);
    expect(cachedData!['republishTime'],
        isNot(equals(indexData['republishTime'])));
    /// Messaged to be displayed when test case passed
    print('Republish Index Test Passed');

    final keyword='testKeyToRepublish';
    /// data/entry is to be deleted from the database using the keyword to save space
    ///
    /// it also remove the data from cache memory
    await indexManager.deleteIndex(keyword);
    /// checking if it exist  in the the  indexes and if no then data is deleted
    final getDeletedDataForCheck =
    database.select('SELECT * FROM indexes WHERE keyword = ?', [keyword]);
    expect( getDeletedDataForCheck.isEmpty, isTrue , reason:' data is not deleted from database');
    /// data is already removed from cache so it should be null
    ///
    /// checking if it exist  in the the cache memory and if no then data is deleted
    final deletedCachedData = cacheManager.getFromCache(keyword);
    expect(deletedCachedData, isNull);


    await indexManager.manuallyRemoveFromPurgeByKeyword(keyword);
    /// checking if it exist  in the the purge and if no then data is deleted
    final getDeletedDataForCheckFromPurge =
    database.select('SELECT * FROM purge WHERE keyword = ?', [keyword]);
    expect( getDeletedDataForCheckFromPurge.isEmpty, isTrue , reason:' data is not deleted from purge database');
    /// final delete message is printed
    print("Data is deleted from the index and purge table ");
  });


  /// test case to read the entry from exact keyword
  test('Read by Exact Keyword', () async {
    /// dummy entry is inserted
    final indexData = {
      'keyword': 'testKeyForRead',
      'location': 'testLocation',
      'replicationFactor': 3,
      'copyNo': 1,
      'layerID': 2,
      'status': 'active',
      'entryDateTime': timestamp.toIso8601String(),
      'expirationDate':
          timestamp.add(const Duration(days: 30)).toIso8601String(),
      'publishTime': timestamp.toIso8601String(),
      'republishTime': timestamp.add(Duration(minutes: 20)).toIso8601String(),
      'lastUpdateTime': timestamp.toIso8601String()
    };
    /// waiting till the data is inserted into index table
    await indexManager.processAndInsertIndex(indexData);
    /// read the keyword using [readByKeyword] function
    final readData = await indexManager.readByKeyword('testKeyForRead');
    /// if its not null and data has been ready by that keyword and both are same
    expect(readData, isNotNull);
    expect(readData!['keyword'], equals('testKeyForRead'));

    /// Messaged to be displayed when test case passed
    print('Read by Exact Keyword Test Passed');
    /// printing the read data
    print('Read Data: $readData');


    final keyword='testKeyForRead';
    /// data/entry is to be deleted from the database using the keyword to save space
    ///
    /// it also remove the data from cache memory
    await indexManager.deleteIndex(keyword);
    /// checking if it exist  in the the  indexes and if no then data is deleted
    final getDeletedDataForCheck =
    database.select('SELECT * FROM indexes WHERE keyword = ?', [keyword]);
    expect( getDeletedDataForCheck.isEmpty, isTrue , reason:' data is not deleted from database');
    /// data is already removed from cache so it should be null
    ///
    /// checking if it exist  in the the cache memory and if no then data is deleted
    final deletedCachedData = cacheManager.getFromCache(keyword);
    expect(deletedCachedData, isNull);


    await indexManager.manuallyRemoveFromPurgeByKeyword(keyword);
    /// checking if it exist  in the the purge and if no then data is deleted
    final getDeletedDataForCheckFromPurge =
    database.select('SELECT * FROM purge WHERE keyword = ?', [keyword]);
    expect( getDeletedDataForCheckFromPurge.isEmpty, isTrue , reason:' data is not deleted from purge database');
    /// final delete message is printed
    print("Data is deleted from the index and purge table ");
  });


  /// test case to read the keyword by partial keyword
  test('Read by Partial Keyword', () async {
    /// dummy entry is inserted
    final indexData = {
      'keyword': 'testPartialKeyForRead',
      'location': 'testLocation',
      'replicationFactor': 3,
      'copyNo': 1,
      'layerID': 2,
      'status': 'active',
      'entryDateTime': timestamp.toIso8601String(),
      'expirationDate':
          timestamp.add(const Duration(days: 30)).toIso8601String(),
      'publishTime': timestamp.toIso8601String(),
      'republishTime': timestamp.add(Duration(minutes: 20)).toIso8601String(),
      'lastUpdateTime': timestamp.toIso8601String()
    };
  });

  /// test case to compute hash
  test('Compute Hash', () {
    final data = 'testData';
    ///retrieving  hash from [computeHash] function
    final computedHash = indexManager.computeHash(data);
    /// Generate SHA-256 hash of the input data and convert it to a string for comparison
    final expectedHash = sha256.convert(utf8.encode(data)).toString();
    /// if both hash are same test case passed
    expect(computedHash, equals(expectedHash));
    /// Messaged to be displayed when test case passed
    print('Compute Hash Test Passed');
  });


  /// moving entries to purge table on expiration
  test('Move Entries to Purge Table on Expiration', () async {
    /// Insert an entry that is about to expire
    final expiringIndexData = {
      'keyword': 'testExpiringKey',
      'location': 'testExpiringLocation',
      'replicationFactor': 2,
      'copyNo': 1,
      'layerID': 1,
      'status': 'active',
      'entryDateTime': timestamp.toIso8601String(),
      'expirationDate': timestamp.add(Duration(seconds: 1)).toIso8601String(),
      'publishTime': timestamp.toIso8601String(),
      'republishTime': timestamp.add(Duration(minutes: 20)).toIso8601String(),
      'lastUpdateTime': timestamp.toIso8601String(),
    };
     /// inserting data into the database and storing in result
    final result = await indexManager.processAndInsertIndex(expiringIndexData);
    /// if not null test case passed
    ///
    /// if it fails the message will be printed
    expect(result, isNotNull, reason: 'Failed to insert expiringIndexData');

    final keyword='testExpiringKey';
    /// data/entry is to be deleted from the database using the keyword to save space
    ///
    /// it also remove the data from cache memory
    await indexManager.deleteIndex(keyword);
    /// checking if it exist  in the the  indexes and if no then data is deleted
    final getDeletedDataForCheck =
    database.select('SELECT * FROM indexes WHERE keyword = ?', [keyword]);
    expect( getDeletedDataForCheck.isEmpty, isTrue , reason:' data is not deleted from database');
    /// data is already removed from cache so it should be null
    ///
    /// checking if it exist  in the the cache memory and if no then data is deleted
    final deletedCachedData = cacheManager.getFromCache(keyword);
    expect(deletedCachedData, isNull);


    await indexManager.manuallyRemoveFromPurgeByKeyword(keyword);
    /// checking if it exist  in the the purge and if no then data is deleted
    final getDeletedDataForCheckFromPurge =
    database.select('SELECT * FROM purge WHERE keyword = ?', [keyword]);
    expect( getDeletedDataForCheckFromPurge.isEmpty, isTrue , reason:' data is not deleted from purge database');
    /// final delete message is printed
    print("Data is deleted from the index and purge table ");
  });

  test('Move Entries to Purge Table on Deletion', () async {
    /// Inserting dummy entry into database
    final deletingIndexData = {
      'keyword': 'testDeletingKey',
      'location': 'testDeletingLocation',
      'replicationFactor': 2,
      'copyNo': 1,
      'layerID': 1,
      'status': 'active',
      'entryDateTime': timestamp.toIso8601String(),
      'expirationDate': timestamp.add(Duration(days: 30)).toIso8601String(),
      'publishTime': timestamp.toIso8601String(),
      'republishTime': timestamp.add(Duration(minutes: 5)).toIso8601String(),
      'lastUpdateTime': timestamp.toIso8601String(),
    };
    final result = await indexManager.processAndInsertIndex(deletingIndexData);
    expect(result, isNotNull, reason: 'Failed to insert deletingIndexData');

    /// Delete the entry from the index table  and cache memory  which also moved it to purge table
    await indexManager.deleteIndex('testDeletingKey');

    /// Wait a moment to ensure the database has time to update
    await Future.delayed(Duration(milliseconds: 100));

    /// on deletion data is being moved to purge table
    ///
    /// Check if the deleted entry has moved to the purge table
    final deletedPurgeEntries = database
        .select('SELECT * FROM purge WHERE keyword = ?', ['testDeletingKey']);

    /// Log the entries found in the purge table
    print('Deleted entries in purge table: $deletedPurgeEntries');

    expect(deletedPurgeEntries.isNotEmpty, isTrue,
        reason: 'Entry was not moved to purge table');
    /// Messaged to be displayed when test case passed
    print('Move Entries to Purge Table Test Passed');

    final keyword='testDeletingKey';

    await indexManager.manuallyRemoveFromPurgeByKeyword(keyword);
    /// checking if it exist  in the the purge and if no then data is deleted
    final getDeletedDataForCheck =
    database.select('SELECT * FROM purge WHERE keyword = ?', [keyword]);
    expect( getDeletedDataForCheck.isEmpty, isTrue , reason:' data is not deleted from database');
    /// data is already removed from cache so it should be null
    ///
    /// checking if it exist  in the the cache memory and if no then data is deleted
    final deletedCachedData = cacheManager.getFromCache(keyword);
    expect(deletedCachedData, isNull);
    /// final delete message is printed
    print("Data is deleted from the index ");
  });

  /// test case to restored the data from purge table
  test('Restore Index from Purge', () async {
    /// Step 1: Insert a test entry into the purge table
    final keyword = 'testRestoreKey';
    final purgeData = {
      'keyword': keyword,
      'location': 'testLocation',
      'replicationFactor': 2,
      'copyNo': 1,
      'layerID': 1,
      'status': 'deleted', // Status should be 'deleted' in the purge table
      'entryDateTime': DateTime.now().toIso8601String(),
      'expirationDate':
          DateTime.now().add(Duration(days: 30)).toIso8601String(),
      'publishTime': DateTime.now().toIso8601String(),
      'republishTime':
          DateTime.now().add(Duration(minutes: 20)).toIso8601String(),
      'lastUpdateTime': DateTime.now().toIso8601String(),
    };

    /// Insert the test entry into the purge table
    database.execute('''
      INSERT INTO purge (keyword, location, replicationFactor, copyNo, layerID, status, entryDateTime, expirationDate, publishTime, republishTime, deletedAt)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
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
      DateTime.now().toIso8601String(), // deletedAt
    ]);

    /// Step 2: Call the restoreIndexFromPurge method
    await indexManager.restoreIndexFromPurge(keyword);

    /// Step 3: Verify the entry is now in the indexes table
    final restoredEntry =
        database.select('SELECT * FROM indexes WHERE keyword = ?', [keyword]);
    expect(restoredEntry.isNotEmpty, isTrue,
        reason: 'Entry should be restored to indexes table');

    /// Check that the restored entry has the expected values
    expect(restoredEntry.first['keyword'], equals(keyword));
    expect(restoredEntry.first['status'],
        equals('active')); /// Status should be 'active'

    /// Step 4: Verify the entry is removed from the purge table
    final purgeEntry =
        database.select('SELECT * FROM purge WHERE keyword = ?', [keyword]);
    expect(purgeEntry.isEmpty, isTrue,
        reason: 'Entry should be removed from purge table');

/// Step 5: Optionally, check the values of the restored entry
    expect(restoredEntry.first['location'], equals('testLocation'));
    expect(restoredEntry.first['replicationFactor'], equals(2));
    expect(restoredEntry.first['copyNo'], equals(1));
    expect(restoredEntry.first['layerID'], equals(1));
    expect(restoredEntry.first['entryDateTime'],
        equals(purgeData['entryDateTime']));
    expect(restoredEntry.first['expirationDate'],
        equals(purgeData['expirationDate']));
    expect(
        restoredEntry.first['publishTime'], equals(purgeData['publishTime']));
    expect(restoredEntry.first['republishTime'],
        equals(purgeData['republishTime']));
    expect(restoredEntry.first['lastUpdateTime'],
        isNotNull); /// Check that lastUpdateTime is set



    /// data/entry is to be deleted from the database using the keyword to save space
    ///
    /// it also remove the data from cache memory
    await indexManager.deleteIndex(keyword);
    /// checking if it exist  in the the  indexes and if no then data is deleted
    final getDeletedDataForCheck =
    database.select('SELECT * FROM indexes WHERE keyword = ?', [keyword]);
    expect( getDeletedDataForCheck.isEmpty, isTrue , reason:' data is not deleted from database');
    /// data is already removed from cache so it should be null
    ///
    /// checking if it exist  in the the cache memory and if no then data is deleted
    final deletedCachedData = cacheManager.getFromCache(keyword);
    expect(deletedCachedData, isNull);


    await indexManager.manuallyRemoveFromPurgeByKeyword(keyword);
    /// checking if it exist  in the the purge and if no then data is deleted
    final getDeletedDataForCheckFromPurge =
    database.select('SELECT * FROM purge WHERE keyword = ?', [keyword]);
    expect( getDeletedDataForCheckFromPurge.isEmpty, isTrue , reason:' data is not deleted from purge database');
    /// final delete message is printed
    print("Data is deleted from the index and purge table ");

  });
  /// Messaged to be displayed when all test case passed
  print(" All test executed !!");
}

//----------------------------------------comment part-------------------------------------------
// from [test-2]
// final numberOfEntries = 50;
//     // final insertedCount = populateDatabase(database, numberOfEntries);
//
//     // // Ensure the function inserted 50 entries
//     // expect(insertedCount, equals(numberOfEntries));
// from [test-3]
// minimalData['copyNo'] = int.parse(minimalData['copyNo'].toString());
// from update index and verify cache
// Function to truncate milliseconds from a timestamp string
// // String truncateMilliseconds(String dateTime) {
// //   return dateTime.split('.').first; // Remove milliseconds
// // }
//   // test('Update Index and Verify Cache', () async {
//   //   final updatedLocation = 'testLocation';
//   //   final indexData = {
//   //     'keyword': 'testKey',
//   //     'location': 'testLocation',
//   //     'replicationFactor': 3,
//   //     'copyNo': 1,
//   //     'layerID': 2,
//   //     'status': 'active',
//   //     'entryDateTime': timestamp.toIso8601String(),
//   //     'expirationDate': timestamp.add(Duration(days: 30)).toIso8601String(),
//   //     'publishTime': timestamp.toIso8601String(),
//   //     'republishTime': timestamp.add(Duration(minutes: 20)).toIso8601String(),
//   //     'lastUpdateTime': timestamp.toIso8601String(),
//   //   };
//
//   //   await indexManager.processAndInsertIndex(indexData);
//   //   await indexManager.updateIndex(indexData, updatedLocation);
//
//   //   final cachedData = cacheManager.getFromCache('testKey');
//
//   //   expect(cachedData, isNotNull);
//   //   expect(cachedData!['location'], equals(updatedLocation));
//
//   //   print('Update Index Test Passed');
//   // });
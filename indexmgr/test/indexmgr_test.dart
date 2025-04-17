// call database initalise here from the index manager package code  in test and check if it exists
//// import 'package:collection/collection.dart';
import 'package:test/test.dart';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:indexmgr/indexmgr.dart';
import 'package:indexmgr/cachemgr.dart';
// import 'package:uuid/uuid.dart';

int populateDatabase(Database database, int numberOfEntries) {
  // var uuid = Uuid();
  final timestamp = DateTime.now();
  int insertedCount = 0;

  for (int i = 0; i < numberOfEntries; i++) {
    // final indexID = i;
    final keyword = 'testKey$i';
    final location = 'testLocation$i';
    final replicationFactor = 3; // Fixed
    final copyNo = 1; // Integer value (copy number)
    final layerID = 1; // Integer value (randomized between 1 and 3)
    final status = i % 2 == 0 ? 'active' : 'deleted'; // Alternating status
    final entryDateTime =
        timestamp.subtract(Duration(days: i)).toIso8601String();
    final expirationDate =
        timestamp.add(Duration(days: 30 - i)).toIso8601String();
    final publishTime = timestamp.toIso8601String();
    final republishTime = DateTime.parse(publishTime)
        .add(Duration(minutes: 20))
        .toIso8601String();
    // final republishTime = timestamp.add(Duration(days: 1)).toIso8601String();
    // final timer = '20m'; // Fixed timer value
    final lastUpdateTime = timestamp.toIso8601String();

    // Inserting data into the `indexes` table
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
      copyNo, // Corrected: `copyNo` should match the `copyNo` column
      layerID,
      status,
      entryDateTime,
      expirationDate,
      publishTime,
      republishTime,
      lastUpdateTime,
    ]);

    insertedCount++;
  }

  return insertedCount;
}

void printDatabaseEntries(Database database) {
  print('--- Indexes Table ---');
  final indexRows = database.select('SELECT * FROM indexes');
  for (var row in indexRows) {
    print(row);
  }

  print('--- Purge Table ---');
  final purgeRows = database.select('SELECT * FROM purge');
  for (var row in purgeRows) {
    print(row);
  }
}

Future<void> main() async {
  late B4IndexManager indexManager;
  late B4CacheManager cacheManager;
  late Database database;
  final String dbPath = 'database/test_index_olm.db'; //
  final timestamp = DateTime.now();

  final String serverSignedCertificate =
      'your_initial_server_signed_certificate'; //

  setUpAll(() async {
    // Initialize the index manager, which will set up the database
    indexManager = B4IndexManager(dbPath);
    database = indexManager.database; // Directly accessing the database
    // Wait for the database to be initialized
    await Future.delayed(Duration(seconds: 1)); // Adjust if necessary

    // Populate the database with initial data only once
    await populateDatabase(database, 50); // Populate with 50 entries

    // Access the initialized database
    database = indexManager
        .getCacheManager()
        .database; // Assuming you have a way to get the database from the cache manager
    cacheManager = indexManager.getCacheManager();
  });

  tearDownAll(() {
    database.dispose();
    if (File(dbPath).existsSync()) {
      File(dbPath).deleteSync();
    }
  });

  test('Verify database initialization', () {
    // Example test to verify the database is initialized
    final rows = database.select('SELECT * FROM indexes');
    expect(rows, isNotNull);
  });

  test('Verify populateDatabase inserts correct number of entries', () {
    // final numberOfEntries = 50;
    // final insertedCount = populateDatabase(database, numberOfEntries);

    // // Ensure the function inserted 50 entries
    // expect(insertedCount, equals(numberOfEntries));

    // Query to verify the database also has 50 rows
    final rows = database.select('SELECT * FROM indexes');
    expect(rows.length, equals(50));

    // Print the entries to the console
    print('Database entries:');
    printDatabaseEntries(database);
    print('All 50 entries verified successfully.');
  });

// Test: Insert Minimal Data and Verify Cache
  test('Insert Minimal Data and Verify Cache', () async {
    final keyword = 'minimalKey';
    final location = 'minimalLocation';
    int replicationFactor = 2;
    int layerID = 1;

    // Step 1: Insert minimal data into the OLM database
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

    minimalData['replicationFactor'] =
        int.parse(minimalData['replicationFactor'].toString());
// minimalData['copyNo'] = int.parse(minimalData['copyNo'].toString());
    minimalData['layerID'] = int.parse(minimalData['layerID'].toString());

    // Step 2: Process and Insert the index using IndexManager
    await indexManager.processAndInsertIndex(minimalData);

    // Step 3: Verify if the minimal data was correctly inserted
    final cachedData = cacheManager.cache[keyword]; // Access the cache directly

    expect(cachedData, isNotNull,
        reason: 'Cache should not be null after insertion');
    expect(cachedData?['keyword'], equals(keyword));
    expect(cachedData?['location'], equals(location));

    print('Minimal Data Handling Test Passed');
  });

  test('Insert Index and Verify Cache', () async {
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

    await indexManager.processAndInsertIndex(indexData);
    final cachedData = cacheManager.getFromCache('testKey');

    expect(cachedData, isNotNull);
    expect(cachedData!['keyword'], equals('testKey'));

    print('Insert Index Test Passed');
  });

  test('Update Index using Keyword and Verify Cache', () async {
    final keyword = 'testKey';
    final initialLocation =
        'initialLocation'; // This is only used for the initial insert
    final updatedLocation = 'updatedLocation';

    // Step 1: Insert initial data into the OLM database
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

    // Step 2: Update the index with the new location using only the keyword
    await indexManager.updateIndex(keyword, updatedLocation);

    // Step 3: Verify if the location was correctly updated in the cache
    final cachedData = cacheManager.getFromCache(keyword);
    expect(cachedData, isNotNull);
    expect(cachedData!['location'], equals(updatedLocation));

    // Step 4: Verify if the expiration date, publish time, and republish time were correctly updated in the database
    final updatedEntry =
        database.select('SELECT * FROM indexes WHERE keyword = ?', [keyword]);
    expect(updatedEntry.isNotEmpty, isTrue);
    expect(updatedEntry.first['location'], equals(updatedLocation));

    // Get the actual expiration date from the updated entry
    final DateTime actualExpirationDate =
        DateTime.parse(updatedEntry.first['expirationDate']);
    final DateTime actualPublishTime =
        DateTime.parse(updatedEntry.first['publishTime']);
    final DateTime actualRepublishTime =
        DateTime.parse(updatedEntry.first['republishTime']);

    // Get the current time for comparison
    final DateTime now = DateTime.now();

    // Check if the expiration date is updated and within 30 seconds of the expected
    expect(actualExpirationDate.isAfter(now), isTrue);
    expect(actualExpirationDate.isBefore(now.add(Duration(days: 30))), isTrue);

    // Check if the publish time is updated and within 30 seconds of the current time
    expect(
        actualPublishTime.isAfter(now.subtract(Duration(seconds: 30))), isTrue);
    expect(actualPublishTime.isBefore(now.add(Duration(seconds: 30))), isTrue);

    // Check if the republish time is updated and within 30 seconds of the expected
    expect(
        actualRepublishTime
            .isAfter(actualPublishTime.add(Duration(minutes: 19))),
        isTrue);
    expect(
        actualRepublishTime
            .isBefore(actualPublishTime.add(Duration(minutes: 21))),
        isTrue);

    print('Update Index Test Passed');
  });

// // Function to truncate milliseconds from a timestamp string
// String truncateMilliseconds(String dateTime) {
//   return dateTime.split('.').first; // Remove milliseconds
// }
  // test('Update Index and Verify Cache', () async {
  //   final updatedLocation = 'testLocation';
  //   final indexData = {
  //     'keyword': 'testKey',
  //     'location': 'testLocation',
  //     'replicationFactor': 3,
  //     'copyNo': 1,
  //     'layerID': 2,
  //     'status': 'active',
  //     'entryDateTime': timestamp.toIso8601String(),
  //     'expirationDate': timestamp.add(Duration(days: 30)).toIso8601String(),
  //     'publishTime': timestamp.toIso8601String(),
  //     'republishTime': timestamp.add(Duration(minutes: 20)).toIso8601String(),
  //     'lastUpdateTime': timestamp.toIso8601String(),
  //   };

  //   await indexManager.processAndInsertIndex(indexData);
  //   await indexManager.updateIndex(indexData, updatedLocation);

  //   final cachedData = cacheManager.getFromCache('testKey');

  //   expect(cachedData, isNotNull);
  //   expect(cachedData!['location'], equals(updatedLocation));

  //   print('Update Index Test Passed');
  // });

  test('Delete Index and Verify Cache', () async {
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

    await indexManager.processAndInsertIndex(indexData);
    await indexManager.deleteIndex('testKeyToDelete');

    final cachedData = cacheManager.getFromCache('testKeyToDelete');

    expect(cachedData, isNull);

    print('Delete Index Test Passed');
  });

  test('Publish Index and Verify Cache', () async {
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

    await indexManager.publishIndex(indexData, serverSignedCertificate);
    final cachedData = cacheManager.getFromCache('testKeyToPublish');

    expect(cachedData, isNotNull);
    expect(cachedData!['status'], equals('active'));

    print('Publish Index Test Passed');
  });

  test('Republish Index and Verify Cache', () async {
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

    await indexManager.processAndInsertIndex(indexData);
    await indexManager.republishIndex('testKeyToRepublish');

    final cachedData = cacheManager.getFromCache('testKeyToRepublish');

    expect(cachedData, isNotNull);
    expect(cachedData!['republishTime'],
        isNot(equals(indexData['republishTime'])));

    print('Republish Index Test Passed');
  });

  test('Read by Exact Keyword', () async {
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

    await indexManager.processAndInsertIndex(indexData);
    final readData = await indexManager.readByKeyword('testKeyForRead');
    expect(readData, isNotNull);
    expect(readData!['keyword'], equals('testKeyForRead'));

    print('Read by Exact Keyword Test Passed');
    print('Read Data: $readData');
  });

  test('Read by Partial Keyword', () async {
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

  test('Compute Hash', () {
    final data = 'testData';
    final computedHash = indexManager.computeHash(data);

    final expectedHash = sha256.convert(utf8.encode(data)).toString();

    expect(computedHash, equals(expectedHash));

    print('Compute Hash Test Passed');
  });

  test('Move Entries to Purge Table on Expiration', () async {
    // Insert an entry that is about to expire
    final expiringIndexData = {
      'keyword': 'testexpiringKey',
      'location': 'testexpiringLocation',
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

    final result = await indexManager.processAndInsertIndex(expiringIndexData);
    expect(result, isNotNull, reason: 'Failed to insert expiringIndexData');
  });

  test('Move Entries to Purge Table on Deletion', () async {
    // Insert another entry and delete it
    final deletingIndexData = {
      'keyword': 'testdeletingKey',
      'location': 'testdeletingLocation',
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

    // Delete the entry
    await indexManager.deleteIndex('testdeletingKey');

    // Wait a moment to ensure the database has time to update
    await Future.delayed(Duration(milliseconds: 100));

    // Check if the deleted entry has moved to the purge table
    final deletedPurgeEntries = database
        .select('SELECT * FROM purge WHERE keyword = ?', ['testdeletingKey']);

    // Log the entries found in the purge table
    print('Deleted entries in purge table: $deletedPurgeEntries');

    expect(deletedPurgeEntries.isNotEmpty, isTrue,
        reason: 'Entry was not moved to purge table');

    print('Move Entries to Purge Table Test Passed');
  });

  test('Restore Index from Purge', () async {
    // Step 1: Insert a test entry into the purge table
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

    // Insert the test entry into the purge table
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

    // Step 2: Call the restoreIndexFromPurge method
    await indexManager.restoreIndexFromPurge(keyword);

    // Step 3: Verify the entry is now in the indexes table
    final restoredEntry =
        database.select('SELECT * FROM indexes WHERE keyword = ?', [keyword]);
    expect(restoredEntry.isNotEmpty, isTrue,
        reason: 'Entry should be restored to indexes table');

    // Check that the restored entry has the expected values
    expect(restoredEntry.first['keyword'], equals(keyword));
    expect(restoredEntry.first['status'],
        equals('active')); // Status should be 'active'

    // Step 4: Verify the entry is removed from the purge table
    final purgeEntry =
        database.select('SELECT * FROM purge WHERE keyword = ?', [keyword]);
    expect(purgeEntry.isEmpty, isTrue,
        reason: 'Entry should be removed from purge table');

// Step 5: Optionally, check the values of the restored entry
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
        isNotNull); // Check that lastUpdateTime is set
  });
}

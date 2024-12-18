import 'package:test/test.dart';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:indexmgr/indexmgr.dart';
import 'package:indexmgr/cachemgr.dart';

Future<void> main() async {
  late B4IndexManager indexManager;
  late B4CacheManager cacheManager;
  late Database database;
  final dbPath = 'database/test_index_olm.db';
  final timestamp = DateTime.now();

  final String serverSignedCertificate =
      'your_initial_server_signed_certificate'; //
  setUpAll(() async {
    //  authManager = AuthManager();
//indexManager = B4IndexManager(dbPath, authManager)
    indexManager = B4IndexManager();
    // await indexManager.verifyOtpAndRetrieveCertificate(otp, selfSignedCertificate, nodeId);
    // await indexManager.publish();
    // Initialize the database connection
    database = sqlite3.open(dbPath);

    // Optionally, create tables if they do not exist
    // await database.execute('CREATE TABLE IF NOT EXISTS ...');
// Create the `indexes` table if it doesn't exist
    database.execute('''
    CREATE TABLE IF NOT EXISTS indexes (
      keyword TEXT PRIMARY KEY,
      location TEXT,
      replicationFactor INTEGER,
      copyNo INTEGER,
      layerID INTEGER,
      status TEXT,
      entryDateTime TEXT,
      expirationDate TEXT,
      publishTime TEXT,
      republishTime TEXT,
      timer TEXT,
      lastUpdateTime TEXT
    )
  ''');
    // Create the `purge` table if it doesn't exist
    database.execute('''
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

    await Future.delayed(const Duration(seconds: 1));
    cacheManager = indexManager.getCacheManager();
  });

  tearDownAll(() {
    database.dispose();
    if (File(dbPath).existsSync()) {
      File(dbPath).deleteSync();
    }
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
      'republishTime': timestamp.add(Duration(days: 1)).toIso8601String(),
      'timer': '20m',
      'lastUpdateTime': timestamp.toIso8601String(),
    };

    await indexManager.insertIndex(indexData);
    final cachedData = cacheManager.getFromCache('testKey');

    expect(cachedData, isNotNull);
    expect(cachedData!['keyword'], equals('testKey'));

    print('Insert Index Test Passed');
  });

  test('Update Index and Verify Cache', () async {
    final updatedLocation = 'testLocation';
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
      'republishTime': timestamp.add(Duration(days: 1)).toIso8601String(),
      'timer': '20m',
      'lastUpdateTime': timestamp.toIso8601String(),
    };

    await indexManager.insertIndex(indexData);
    await indexManager.updateIndex(indexData, updatedLocation);

    final cachedData = cacheManager.getFromCache('testKey');

    expect(cachedData, isNotNull);
    expect(cachedData!['location'], equals(updatedLocation));

    print('Update Index Test Passed');
  });

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
      'republishTime': timestamp.add(Duration(days: 1)).toIso8601String(),
      'timer': '20m',
      'lastUpdateTime': timestamp.toIso8601String(),
    };

    await indexManager.insertIndex(indexData);
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
      'republishTime': timestamp.add(Duration(days: 1)).toIso8601String(),
      'timer': '20m',
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
      'republishTime': timestamp.add(Duration(days: 1)).toIso8601String(),
      'timer': '20m',
      'lastUpdateTime': timestamp.toIso8601String(),
    };

    await indexManager.insertIndex(indexData);
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
      'status': 'publish',
      'entryDateTime': timestamp.toIso8601String(),
      'expirationDate':
          timestamp.add(const Duration(days: 30)).toIso8601String(),
      'publishTime': timestamp.toIso8601String(),
      'republishTime': timestamp.add(const Duration(days: 1)).toIso8601String(),
      'timer': '20m',
      'lastUpdateTime': timestamp.toIso8601String()
    };

    await indexManager.insertIndex(indexData);
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
      'status': 'publish',
      'entryDateTime': timestamp.toIso8601String(),
      'expirationDate':
          timestamp.add(const Duration(days: 30)).toIso8601String(),
      'publishTime': timestamp.toIso8601String(),
      'republishTime': timestamp.add(const Duration(days: 1)).toIso8601String(),
      'timer': '20m',
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

  test('Purging Expired and Deleted Indexes', () async {
    final expiredIndex = {
      'keyword': 'expiredKey',
      'location': 'expiredLocation',
      'status': 'active',
      'expirationDate': timestamp.subtract(Duration(days: 1)).toIso8601String(),
    };

    final deletedIndex = {
      'keyword': 'deletedKey',
      'location': 'deletedLocation',
      'status': 'deleted',
      'expirationDate': timestamp.toIso8601String(),
    };

    await indexManager.insertIndex(expiredIndex);
    await indexManager.insertIndex(deletedIndex);

    await indexManager.purgeIndexes();

    final purgedData = database.select(
      'SELECT * FROM purge WHERE keyword IN (?, ?)',
      ['expiredKey', 'deletedKey'],
    );

    expect(purgedData.length, equals(0));

    print('Purging Expired and Deleted Indexes Test Passed');
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:indexmgr/indexmgr.dart';
import 'package:crypto/crypto.dart';
import 'package:index_manager/cache_manager.dart';
import 'package:test/test.dart';
import 'dart:io';
import 'dart:convert';
import 'package:sqlite3/sqlite3.dart';

//import 'package:index_manager/index_manager.dart'; // Adjust the path to your main Dart file
/*
void main() {
  test('adds one to input values', () {
    final calculator = Calculator();
    expect(calculator.addOne(2), 3);
    expect(calculator.addOne(-7), -6);
    expect(calculator.addOne(0), 1);
  });
}
*/
void main() {
  late B4IndexManager indexManager;
  late B4CacheManager cacheManager;
  late Database database;
  setUp(() async {
    final dbPath = 'database/test.db';
    indexManager = B4IndexManager(dbPath);
    await Future.delayed(Duration(seconds: 1)); // Wait for initialization
    cacheManager = indexManager
        .getCacheManager(); // Use a public method to get the cache manager
  });

  tearDown(() async {
    final dbPath = 'database/test.db';
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
      'status': 'publish',
      'entryDateTime': DateTime.now().toString(),
      'expirationDate': DateTime.now().add(Duration(days: 30)).toString(),
      'publishTime': DateTime.now().toString(),
      'republishTime': DateTime.now().add(Duration(days: 1)).toString(),
      'timer': '20m',
      'lastUpdateTime': DateTime.now().toString()
    };

    await indexManager.insertIndex(indexData);

    final cachedData = cacheManager.getFromCache('testKey');
    expect(cachedData, isNotNull);
    expect(cachedData!['keyword'], equals('testKey'));

    print('Insert Index Test Passed');
    print('Inserted Data: $indexData');
    print('Cached Data: $cachedData');
  });

  test('Update Index and Verify Cache', () async {
    final updatedLocation = 'updatedLocation';
    final indexData = {
      'keyword': 'testKey',
      'location': 'testLocation',
      'replicationFactor': 3,
      'copyNo': 1,
      'layerID': 2,
      'status': 'publish',
      'entryDateTime': DateTime.now().toString(),
      'expirationDate': DateTime.now().add(Duration(days: 30)).toString(),
      'publishTime': DateTime.now().toString(),
      'republishTime': DateTime.now().add(Duration(days: 1)).toString(),
      'timer': '20m',
      'lastUpdateTime': DateTime.now().toString()
    };

    await indexManager.insertIndex(indexData);
    await indexManager.updateIndex(indexData, updatedLocation);

    final cachedData = cacheManager.getFromCache('testKey');
    expect(cachedData, isNotNull);
    expect(cachedData!['location'], equals(updatedLocation));

    print('Update Index Test Passed');
    print('Original Data: $indexData');
    print('Updated Data: ${cachedData}');
  });

  test('Delete Index and Verify Cache', () async {
    final indexData = {
      'keyword': 'testKeyToDelete',
      'location': 'testLocation',
      'replicationFactor': 3,
      'copyNo': 1,
      'layerID': 2,
      'status': 'publish',
      'entryDateTime': DateTime.now().toString(),
      'expirationDate': DateTime.now().add(Duration(days: 30)).toString(),
      'publishTime': DateTime.now().toString(),
      'republishTime': DateTime.now().add(Duration(days: 1)).toString(),
      'timer': '20m',
      'lastUpdateTime': DateTime.now().toString()
    };

    await indexManager.insertIndex(indexData);
    await indexManager.deleteIndex('testKeyToDelete');

    final cachedData = cacheManager.getFromCache('testKeyToDelete');
    expect(cachedData, isNull);

    print('Delete Index Test Passed');
    print('Data Deleted: $indexData');
  });

  test('Publish Index and Verify Cache', () async {
    final indexData = {
      'keyword': 'testKeyToPublish',
      'location': 'testLocation',
      'replicationFactor': 3,
      'copyNo': 1,
      'layerID': 2,
      'status': 'publish',
      'entryDateTime': DateTime.now().toString(),
      'expirationDate': DateTime.now().add(Duration(days: 30)).toString(),
      'publishTime': DateTime.now().toString(),
      'republishTime': DateTime.now().add(Duration(days: 1)).toString(),
      'timer': '20m',
      'lastUpdateTime': DateTime.now().toString()
    };

    await indexManager.publishIndex(indexData);

    final cachedData = cacheManager.getFromCache('testKeyToPublish');
    expect(cachedData, isNotNull);
    expect(cachedData!['status'], equals('publish'));

    print('Publish Index Test Passed');
    print('Published Data: $indexData');
    print('Cached Data After Publish: $cachedData');
  });

  test('Republish Index and Verify Cache', () async {
    final indexData = {
      'keyword': 'testKeyToRepublish',
      'location': 'testLocation',
      'replicationFactor': 3,
      'copyNo': 1,
      'layerID': 2,
      'status': 'publish',
      'entryDateTime': DateTime.now().toString(),
      'expirationDate': DateTime.now().add(Duration(days: 30)).toString(),
      'publishTime': DateTime.now().toString(),
      'republishTime': DateTime.now().add(Duration(days: 1)).toString(),
      'timer': '20m',
      'lastUpdateTime': DateTime.now().toString()
    };

    await indexManager.publishIndex(indexData);
    await indexManager.republishIndex('testKeyToRepublish');

    final cachedData = cacheManager.getFromCache('testKeyToRepublish');
    expect(cachedData, isNotNull);
    expect(
        cachedData!['republishTime'], isNot(equals(DateTime.now().toString())));

    print('Republish Index Test Passed');
    print('Republished Data: $indexData');
    print('Cached Data After Republish: $cachedData');
  });

  test('Purge Expired Indexes', () async {
    final pastDate =
        DateTime.now().subtract(Duration(days: 31)).toIso8601String();
    final indexData = {
      'keyword': 'expiredKey',
      'location': 'testLocation',
      'replicationFactor': 3,
      'copyNo': 1,
      'layerID': 2,
      'status': 'publish',
      'entryDateTime':
          DateTime.now().subtract(Duration(days: 31)).toIso8601String(),
      'expirationDate': pastDate,
      'publishTime':
          DateTime.now().subtract(Duration(days: 31)).toIso8601String(),
      'republishTime':
          DateTime.now().subtract(Duration(days: 30)).toIso8601String(),
      'timer': '20m',
      'lastUpdateTime':
          DateTime.now().subtract(Duration(days: 31)).toIso8601String()
    };

    await indexManager.insertIndex(indexData);

    // Trigger purge
    await indexManager.purgeExpiredIndexes();

    // Verify that the expired index was removed
    final cachedData = cacheManager.getFromCache('expiredKey');
    expect(cachedData, isNull);

    print('Purge Expired Indexes Test Passed');
    print('Expired Index Data: $indexData');
  });

  test('Read by Keyword', () async {
    final indexData = {
      'keyword': 'testKeyForRead',
      'location': 'testLocation',
      'replicationFactor': 3,
      'copyNo': 1,
      'layerID': 2,
      'status': 'publish',
      'entryDateTime': DateTime.now().toString(),
      'expirationDate': DateTime.now().add(Duration(days: 30)).toString(),
      'publishTime': DateTime.now().toString(),
      'republishTime': DateTime.now().add(Duration(days: 1)).toString(),
      'timer': '20m',
      'lastUpdateTime': DateTime.now().toString()
    };

    await indexManager.insertIndex(indexData);
    final readData = await indexManager.readByKeyword('testKeyForRead');
    expect(readData, isNotNull);
    expect(readData!['keyword'], equals('testKeyForRead'));

    print('Read by Keyword Test Passed');
    print('Read Data: $readData');
  });

  test('Compute Hash', () {
    final indexData = 'data';
    final hash = indexManager.computeHash(indexData);

    final bytes = utf8.encode(indexData); // Convert location string to bytes
    final expectedHash =
        sha256.convert(bytes).toString(); // Compute SHA-256 hash

    expect(hash, equals(expectedHash));

    print('Compute Hash Test Passed');
    print('indexData: $indexData');
    print('Computed Hash: $hash');
    print('Expected Hash: $expectedHash');
  });

  test('Restore from Purge', () async {
    final indexData = {
      'keyword': 'testKeyToPurge',
      'location': 'testLocation',
      'replicationFactor': 3,
      'copyNo': 1,
      'layerID': 2,
      'status': 'publish',
      'entryDateTime': DateTime.now().toString(),
      'expirationDate': DateTime.now().add(Duration(days: 30)).toString(),
      'publishTime': DateTime.now().toString(),
      'republishTime': DateTime.now().add(Duration(days: 1)).toString(),
      'timer': '20m',
      'lastUpdateTime': DateTime.now().toString()
    };

    await indexManager.insertIndex(indexData);
    await indexManager.deleteIndex('testKeyToPurge');
    await indexManager.purgeDeletedIndexes(); // Simulate purging

    await indexManager.restoreIndexFromPurge('testKeyToPurge'); // Restore index
    final readData = await indexManager.readByKeyword('testKeyToPurge');
    expect(readData, isNotNull);
    expect(readData!['keyword'], equals('testKeyToPurge'));

    print('Restore from Purge Test Passed');
    print('Restored Data: $readData');
  });
}

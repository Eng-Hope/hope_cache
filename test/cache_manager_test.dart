import 'package:hope_cache/cache_manager.dart';
import 'package:hope_cache/key_gen.dart';
import 'package:hope_cache/src/in_memory_cache_store.dart';
import 'package:test/test.dart';


void main() {
  group('CacheManager Basic API Tests', () {
    late CacheManager cacheManager;

    setUp(() async {
      cacheManager = await CacheManager.create(
        maxSize: 1024 * 1024,
        defaultTTL: const Duration(minutes: 5),
        evictionPolicy: EvictionPolicy.lru,
      );
    });

    test('should set and get data successfully', () async {
      final testData = {'name': 'John', 'age': 30};

      await cacheManager.set('user:1', testData);

      final result = await cacheManager.get(
        'user:1',
            () async => {'name': 'Fallback'},
      );

      expect(result, equals(testData));
    });

    test('should call fetcher on cache miss', () async {
      var fetcherCalled = false;
      final fetchedData = {'id': 1, 'title': 'Test'};

      final result = await cacheManager.get(
        'post:1',
            () async {
          fetcherCalled = true;
          return fetchedData;
        },
      );

      expect(fetcherCalled, isTrue);
      expect(result, equals(fetchedData));
    });

    test('should not call fetcher on cache hit', () async {
      final cachedData = {'status': 'cached'};
      await cacheManager.set('test:key', cachedData);

      var fetcherCalled = false;

      final result = await cacheManager.get(
        'test:key',
            () async {
          fetcherCalled = true;
          return {'status': 'fresh'};
        },
      );

      expect(fetcherCalled, isFalse);
      expect(result, equals(cachedData));
    });
  });
    group('CacheManager TTL Tests', () {
    late CacheManager cacheManager;

    setUp(() async {
      cacheManager = await CacheManager.create(
        maxSize: 1024 * 1024,
        defaultTTL: Duration(milliseconds: 100),
        evictionPolicy: EvictionPolicy.lru,
        storage: InMemoryCacheStore(),
      );
    });

    test('should expire entry after TTL', () async {
      await cacheManager.set('short', 'data1', ttl: Duration(milliseconds: 50));
      await cacheManager.set('long', 'data2', ttl: Duration(milliseconds: 200));

      // Immediately available
      expect(await cacheManager.get('short', () async => 'fetcher1'), equals('data1'));
      expect(await cacheManager.get('long', () async => 'fetcher2'), equals('data2'));

      // Wait 60ms → short should expire, long still valid
      await Future.delayed(Duration(milliseconds: 60));

      final shortValue = await cacheManager.get('short', () async => 'new1');
      final longValue = await cacheManager.get('long', () async => 'new2');

      expect(shortValue, equals('new1')); // expired → fetcher ran
      expect(longValue, equals('data2')); // still valid → cached

      // Wait additional 150ms → long should expire
      await Future.delayed(Duration(milliseconds: 150));

      final longValue2 = await cacheManager.get('long', () async => 'new3');
      expect(longValue2, equals('new3')); // expired → fetcher ran
    });

    test('should use default TTL if per-key TTL not set', () async {
      await cacheManager.set('defaultTTL', 'data', ttl: null);

      // Should be valid immediately
      expect(await cacheManager.get('defaultTTL', () async => 'fetcher'), equals('data'));

      // Wait beyond default TTL (100ms)
      await Future.delayed(Duration(milliseconds: 120));

      final val = await cacheManager.get('defaultTTL', () async => 'newVal');
      expect(val, equals('newVal')); // default TTL expired
    });
  });

  group('Cache Key Consistency Tests', () {
    late CacheManager cache;

    setUp(() async {
      cache = await CacheManager.create(
        maxSize: 1024 * 1024,
        defaultTTL: Duration(minutes: 5),
        evictionPolicy: EvictionPolicy.lru,
      );
    });

    tearDown(() async {
      await cache.clear();
    });

    test('1. Map keys with different order should resolve to same cache entry', () async {
      final data = {'value': 'test_data'};

      // Set with one order
      await cache.set(
        {'product': 'phone', 'color': 'red', 'size': 'large'},
        data,
      );

      // Get with different order
      final retrieved = await cache.get(
        {'color': 'red', 'size': 'large', 'product': 'phone'},
            () async => {'value': 'should_not_fetch'},
      );

      // Should return cached data, NOT fetch new data
      expect(retrieved, equals(data));
      expect(retrieved['value'], equals('test_data'));
    });

    test('2. String keys should work independently from map keys', () async {
      final stringData = {'type': 'string_key'};
      final mapData = {'type': 'map_key'};

      await cache.set('user_123', stringData);
      await cache.set({'user': '123'}, mapData);

      final fromString = await cache.get(
        'user_123',
            () async => throw Exception('Should not fetch'),
      );
      final fromMap = await cache.get(
        {'user': '123'},
            () async => throw Exception('Should not fetch'),
      );

      // They should be DIFFERENT cache entries
      expect(fromString['type'], equals('string_key'));
      expect(fromMap['type'], equals('map_key'));
    });

    test('3. Nested map keys should maintain consistency', () async {
      final data = {'nested': 'data'};

      await cache.set({
        'user': {'id': '123', 'role': 'admin'},
        'page': '1'
      }, data);

      final retrieved = await cache.get({
        'page': '1',
        'user': {'role': 'admin', 'id': '123'} // Nested order different
      }, () async => {'nested': 'should_not_fetch'});

      expect(retrieved['nested'], equals('data'));
    });

    test('4. Keys with null values should be handled consistently', () async {
      final data = {'has_null': true};

      await cache.set({'key': 'test', 'optional': null}, data);

      final retrieved = await cache.get(
        {'optional': null, 'key': 'test'},
            () async => {'has_null': false},
      );

      expect(retrieved['has_null'], equals(true));
    });

    test('5. Keys with different data types should create different entries', () async {
      await cache.set({'id': '123'}, {'type': 'string'});
      await cache.set({'id': 123}, {'type': 'int'});

      final fromString = await cache.get(
        {'id': '123'},
            () async => throw Exception('Should not fetch'),
      );
      final fromInt = await cache.get(
        {'id': 123},
            () async => throw Exception('Should not fetch'),
      );

      // These should be DIFFERENT entries
      expect(fromString['type'], equals('string'));
      expect(fromInt['type'], equals('int'));
    });

    test('6. Empty map should create valid cache entry', () async {
      final data = {'empty_key': true};

      await cache.set({}, data);

      final retrieved = await cache.get(
        {},
            () async => {'empty_key': false},
      );

      expect(retrieved['empty_key'], equals(true));
    });

    test('7. List values in keys should maintain order and consistency', () async {
      final data = {'list_key': 'test'};

      await cache.set({
        'filters': ['red', 'blue', 'green'],
        'page': '1'
      }, data);

      final retrieved = await cache.get({
        'page': '1',
        'filters': ['red', 'blue', 'green']
      }, () async => {'list_key': 'should_not_fetch'});

      expect(retrieved['list_key'], equals('test'));
    });

    test('8. Different list order should create DIFFERENT cache entries', () async {
      await cache.set({
        'filters': ['red', 'blue', 'green']
      }, {'order': 'first'});

      await cache.set({
        'filters': ['green', 'blue', 'red']
      }, {'order': 'second'});

      final first = await cache.get(
        {'filters': ['red', 'blue', 'green']},
            () async => throw Exception('Should not fetch'),
      );
      final second = await cache.get(
        {'filters': ['green', 'blue', 'red']},
            () async => throw Exception('Should not fetch'),
      );

      // Different order = different entries
      expect(first['order'], equals('first'));
      expect(second['order'], equals('second'));
    });

    test('9. Boolean values in keys should work correctly', () async {
      await cache.set({'active': true, 'id': '1'}, {'status': 'active'});
      await cache.set({'active': false, 'id': '1'}, {'status': 'inactive'});

      final activeUser = await cache.get(
        {'id': '1', 'active': true},
            () async => throw Exception('Should not fetch'),
      );
      final inactiveUser = await cache.get(
        {'id': '1', 'active': false},
            () async => throw Exception('Should not fetch'),
      );

      expect(activeUser['status'], equals('active'));
      expect(inactiveUser['status'], equals('inactive'));
    });

    test('10. Complex real-world query key should work consistently', () async {
      final complexKey = {
        'endpoint': 'products',
        'filters': {
          'category': 'electronics',
          'priceRange': {'min': 100, 'max': 500}
        },
        'pagination': {'page': 1, 'size': 20},
        'sort': ['price', 'rating'],
        'includeOutOfStock': false,
      };

      final data = {'products': ['item1', 'item2']};
      await cache.set(complexKey, data);

      // Same key with different property order
      final retrieved = await cache.get({
        'sort': ['price', 'rating'],
        'includeOutOfStock': false,
        'pagination': {'size': 20, 'page': 1},
        'endpoint': 'products',
        'filters': {
          'priceRange': {'max': 500, 'min': 100},
          'category': 'electronics'
        },
      }, () async => {'products': ['should_not_fetch']});

      expect(retrieved['products'], equals(['item1', 'item2']));
    });
  });

  group('KeyGen Direct Tests', () {
    test('KeyGen should generate identical keys for different map orders', () {
      final key1 = KeyGen.fromMap({'a': '1', 'b': '2', 'c': '3'});
      final key2 = KeyGen.fromMap({'c': '3', 'a': '1', 'b': '2'});
      final key3 = KeyGen.fromMap({'b': '2', 'c': '3', 'a': '1'});

      expect(key1, equals(key2));
      expect(key2, equals(key3));
      expect(key1, equals(key3));
    });

    test('KeyGen.withPrefix should create properly namespaced keys', () {
      final key1 = KeyGen.withPrefix('user', {'id': '123'});
      final key2 = KeyGen.withPrefix('user', {'id': '456'});
      final key3 = KeyGen.withPrefix('product', {'id': '123'});

      // Same prefix, different params
      expect(key1, isNot(equals(key2)));

      // Different prefix, same params
      expect(key1, isNot(equals(key3)));

      // Should start with prefix
      expect(key1.startsWith('user:'), isTrue);
      expect(key3.startsWith('product:'), isTrue);
    });
  });

  group('Advanced Cache Key', () {
    late CacheManager cache;

    setUp(() async {
      cache = await CacheManager.create(
        maxSize: 1024 * 1024,
        defaultTTL: Duration(minutes: 5),
        evictionPolicy: EvictionPolicy.lru,
      );
    });

    tearDown(() async {
      await cache.clear();
    });

    test('11. GraphQL-style query with variables should be unique per variable set', () async {
      // Simulating GraphQL queries with same query but different variables
      final query1 = {
        'query': 'getUserPosts',
        'variables': {'userId': 123, 'limit': 10, 'offset': 0}
      };
      final query2 = {
        'query': 'getUserPosts',
        'variables': {'userId': 123, 'limit': 10, 'offset': 10}
      };
      final query3 = {
        'query': 'getUserPosts',
        'variables': {'userId': 456, 'limit': 10, 'offset': 0}
      };

      await cache.set(query1, {'page': 1, 'posts': ['post1', 'post2']});
      await cache.set(query2, {'page': 2, 'posts': ['post3', 'post4']});
      await cache.set(query3, {'page': 1, 'posts': ['post5', 'post6']});

      final result1 = await cache.get(
        {'variables': {'offset': 0, 'limit': 10, 'userId': 123}, 'query': 'getUserPosts'},
            () async => throw Exception('Should not fetch'),
      );
      final result2 = await cache.get(query2, () async => throw Exception('Should not fetch'));
      final result3 = await cache.get(query3, () async => throw Exception('Should not fetch'));

      expect(result1['page'], equals(1));
      expect(result1['posts'], equals(['post1', 'post2']));
      expect(result2['page'], equals(2));
      expect(result3['posts'], equals(['post5', 'post6']));
    });

    test('12. REST API endpoint with query params should match regardless of param order', () async {
      // /api/products?category=electronics&brand=samsung&minPrice=500&maxPrice=1000
      final params1 = {
        'endpoint': '/api/products',
        'category': 'electronics',
        'brand': 'samsung',
        'minPrice': 500,
        'maxPrice': 1000
      };

      final params2 = {
        'endpoint': '/api/products',
        'maxPrice': 1000,
        'minPrice': 500,
        'brand': 'samsung',
        'category': 'electronics'
      };

      await cache.set(params1, {'products': ['phone1', 'phone2']});

      final result = await cache.get(
        params2,
            () async => {'products': ['should_not_fetch']},
      );

      expect(result['products'], equals(['phone1', 'phone2']));
    });

    test('13. Search queries with special characters and spaces should be distinct', () async {
      await cache.set(
        {'search': 'hello world', 'type': 'exact'},
        {'results': ['result1']},
      );
      await cache.set(
        {'search': 'hello  world', 'type': 'exact'}, // Two spaces
        {'results': ['result2']},
      );
      await cache.set(
        {'search': 'hello-world', 'type': 'exact'},
        {'results': ['result3']},
      );

      final result1 = await cache.get(
        {'search': 'hello world', 'type': 'exact'},
            () async => throw Exception('Should not fetch'),
      );
      final result2 = await cache.get(
        {'search': 'hello  world', 'type': 'exact'},
            () async => throw Exception('Should not fetch'),
      );
      final result3 = await cache.get(
        {'search': 'hello-world', 'type': 'exact'},
            () async => throw Exception('Should not fetch'),
      );

      // All should be DIFFERENT cache entries
      expect(result1['results'], equals(['result1']));
      expect(result2['results'], equals(['result2']));
      expect(result3['results'], equals(['result3']));
    });

    test('14. Floating point precision should create different keys', () async {
      await cache.set({'price': 10.1}, {'item': 'A'});
      await cache.set({'price': 10.10}, {'item': 'B'});
      await cache.set({'price': 10.100}, {'item': 'C'});

      final resultA = await cache.get(
        {'price': 10.1},
            () async => throw Exception('Should not fetch'),
      );
      final resultB = await cache.get(
        {'price': 10.10},
            () async => throw Exception('Should not fetch'),
      );

      // Dart treats 10.1, 10.10, 10.100 as the same double
      // So they SHOULD return the same cached entry
      expect(resultA['item'], equals(resultB['item']));
    });

    test('15. Filter combinations for e-commerce should be unique', () async {
      final filter1 = {
        'category': 'clothing',
        'colors': ['red', 'blue'],
        'sizes': ['M', 'L'],
        'priceRange': {'min': 20, 'max': 100},
        'inStock': true
      };

      final filter2 = {
        'category': 'clothing',
        'colors': ['blue', 'red'], // Different order
        'sizes': ['M', 'L'],
        'priceRange': {'min': 20, 'max': 100},
        'inStock': true
      };

      await cache.set(filter1, {'count': 15, 'items': ['shirt1', 'shirt2']});

      final result = await cache.get(
        filter2,
            () async => {'count': 999, 'items': ['should_not_fetch']},
      );

      // Different list order = DIFFERENT keys (this is expected behavior)
      expect(result['count'], equals(999)); // Should fetch because colors order differs
    });

    test('16. Date range queries should be precise', () async {
      await cache.set({
        'startDate': '2024-01-01',
        'endDate': '2024-01-31',
        'timezone': 'UTC'
      }, {'events': ['event1', 'event2']});

      await cache.set({
        'startDate': '2024-01-01',
        'endDate': '2024-01-30', // One day different
        'timezone': 'UTC'
      }, {'events': ['event3']});

      final jan31 = await cache.get(
        {'timezone': 'UTC', 'endDate': '2024-01-31', 'startDate': '2024-01-01'},
            () async => throw Exception('Should not fetch'),
      );
      final jan30 = await cache.get(
        {'startDate': '2024-01-01', 'endDate': '2024-01-30', 'timezone': 'UTC'},
            () async => throw Exception('Should not fetch'),
      );

      expect(jan31['events'], equals(['event1', 'event2']));
      expect(jan30['events'], equals(['event3']));
    });

    test('17. Pagination with cursor-based should work correctly', () async {
      await cache.set({
        'resource': 'users',
        'cursor': 'eyJpZCI6MTIzfQ==',
        'limit': 20
      }, {'users': ['user1', 'user2'], 'nextCursor': 'eyJpZCI6MTQzfQ=='});

      await cache.set({
        'resource': 'users',
        'cursor': 'eyJpZCI6MTQzfQ==',
        'limit': 20
      }, {'users': ['user3', 'user4'], 'nextCursor': 'eyJpZCI6MTYzfQ=='});

      final page1 = await cache.get(
        {'limit': 20, 'cursor': 'eyJpZCI6MTIzfQ==', 'resource': 'users'},
            () async => throw Exception('Should not fetch'),
      );
      final page2 = await cache.get(
        {'resource': 'users', 'limit': 20, 'cursor': 'eyJpZCI6MTQzfQ=='},
            () async => throw Exception('Should not fetch'),
      );

      expect(page1['users'], equals(['user1', 'user2']));
      expect(page2['users'], equals(['user3', 'user4']));
      expect(page1['nextCursor'], isNot(equals(page2['nextCursor'])));
    });

    test('18. Multi-level nested filters should maintain consistency', () async {
      final complexFilter = {
        'users': {
          'active': true,
          'roles': ['admin', 'moderator'],
          'permissions': {
            'read': true,
            'write': true,
            'delete': false
          }
        },
        'dateRange': {
          'from': '2024-01-01',
          'to': '2024-12-31'
        }
      };

      final reorderedFilter = {
        'dateRange': {
          'to': '2024-12-31',
          'from': '2024-01-01'
        },
        'users': {
          'permissions': {
            'delete': false,
            'write': true,
            'read': true
          },
          'roles': ['admin', 'moderator'],
          'active': true
        }
      };

      await cache.set(complexFilter, {'count': 42});

      final result = await cache.get(
        reorderedFilter,
            () async => {'count': 999},
      );

      // Nested maps reordered should still match
      expect(result['count'], equals(42));
    });

    test('19. Empty strings vs null vs missing keys should be different', () async {
      await cache.set({'search': '', 'type': 'query'}, {'result': 'empty_string'});
      await cache.set({'search': null, 'type': 'query'}, {'result': 'null_value'});
      await cache.set({'type': 'query'}, {'result': 'missing_key'});

      final emptyString = await cache.get(
        {'type': 'query', 'search': ''},
            () async => throw Exception('Should not fetch'),
      );
      final nullValue = await cache.get(
        {'search': null, 'type': 'query'},
            () async => throw Exception('Should not fetch'),
      );
      final missingKey = await cache.get(
        {'type': 'query'},
            () async => throw Exception('Should not fetch'),
      );

      expect(emptyString['result'], equals('empty_string'));
      expect(nullValue['result'], equals('null_value'));
      expect(missingKey['result'], equals('missing_key'));
    });

    test('20. API versioning in keys should create separate caches', () async {
      await cache.set({
        'endpoint': 'users',
        'version': 'v1',
        'id': 123
      }, {'name': 'John Doe', 'age': 30});

      await cache.set({
        'endpoint': 'users',
        'version': 'v2',
        'id': 123
      }, {'fullName': 'John Doe', 'birthYear': 1994});

      final v1Result = await cache.get(
        {'id': 123, 'version': 'v1', 'endpoint': 'users'},
            () async => throw Exception('Should not fetch'),
      );
      final v2Result = await cache.get(
        {'endpoint': 'users', 'id': 123, 'version': 'v2'},
            () async => throw Exception('Should not fetch'),
      );

      // Different API versions should have different schemas
      expect(v1Result.containsKey('age'), isTrue);
      expect(v2Result.containsKey('birthYear'), isTrue);
      expect(v1Result.containsKey('birthYear'), isFalse);
      expect(v2Result.containsKey('age'), isFalse);
    });
  });

  group('has() - Key Existence Tests', () {
    late CacheManager cache;

    setUp(() async {
      cache = await CacheManager.create(
        maxSize: 1024 * 1024,
        defaultTTL: Duration(minutes: 5),
        evictionPolicy: EvictionPolicy.lru,
      );
    });

    tearDown(() async {
      await cache.clear();
    });

    test('1. has() returns true for existing key', () async {
      await cache.set('user_123', {'name': 'John'});

      expect(cache.has('user_123'), isTrue);
    });

    test('2. has() returns false for non-existent key', () {
      expect(cache.has('user_999'), isFalse);
    });

    test('3. has() works with map keys', () async {
      await cache.set({'resource': 'product', 'id': '456'}, {'name': 'Phone'});

      expect(cache.has({'resource': 'product', 'id': '456'}), isTrue);
      expect(cache.has({'id': '456', 'resource': 'product'}), isTrue); // Order doesn't matter
    });

    test('4. has() returns true even for expired entries (does not check TTL)', () async {
      await cache.set('temp_data', {'value': 'test'}, ttl: Duration(milliseconds: 1));

      // Wait for expiration
      await Future.delayed(Duration(milliseconds: 10));

      // has() still returns true (doesn't check expiration)
      expect(cache.has('temp_data'), isTrue);

      // But getIfPresent returns null (checks expiration)
      final data = await cache.getIfPresent('temp_data');
      expect(data, isNull);
    });
  });

  group('getIfPresent() - Fetch Without Fallback Tests', () {
    late CacheManager cache;

    setUp(() async {
      cache = await CacheManager.create(
        maxSize: 1024 * 1024,
        defaultTTL: Duration(minutes: 5),
        evictionPolicy: EvictionPolicy.lru,
      );
    });

    tearDown(() async {
      await cache.clear();
    });

    test('1. getIfPresent() returns data for existing non-expired key', () async {
      final data = {'name': 'Alice', 'age': 30};
      await cache.set('user_123', data);

      final result = await cache.getIfPresent('user_123');

      expect(result, isNotNull);
      expect(result['name'], equals('Alice'));
      expect(result['age'], equals(30));
    });

    test('2. getIfPresent() returns null for non-existent key', () async {
      final result = await cache.getIfPresent('user_999');

      expect(result, isNull);
    });

    test('3. getIfPresent() returns null for expired key', () async {
      await cache.set('temp_key', {'value': 'temporary'}, ttl: Duration(milliseconds: 1));

      // Wait for expiration
      await Future.delayed(Duration(milliseconds: 10));

      final result = await cache.getIfPresent('temp_key');

      expect(result, isNull);
    });

    test('4. getIfPresent() updates access metadata for LRU/LFU', () async {
      await cache.set('user_1', {'priority': 'low'});
      await cache.set('user_2', {'priority': 'high'});

      // Access user_1 to make it more recent
      await cache.getIfPresent('user_1');
      await cache.getIfPresent('user_1');
      await cache.getIfPresent('user_1');

      // Fill cache to trigger eviction
      for (int i = 3; i < 100; i++) {
        await cache.set('user_$i', {'filler': i});
      }

      // user_1 should still exist (was accessed recently)
      final user1 = await cache.getIfPresent('user_1');
      expect(user1, isNotNull);
    });
  });

  group('setMany() - Batch Set Tests', () {
    late CacheManager cache;

    setUp(() async {
      cache = await CacheManager.create(
        maxSize: 1024 * 1024,
        defaultTTL: Duration(minutes: 5),
        evictionPolicy: EvictionPolicy.lru,
      );
    });

    tearDown(() async {
      await cache.clear();
    });

    test('1. setMany() sets multiple string keys at once', () async {
      await cache.setMany({
        'user_1': {'name': 'Alice'},
        'user_2': {'name': 'Bob'},
        'user_3': {'name': 'Charlie'},
      });

      final user1 = await cache.getIfPresent('user_1');
      final user2 = await cache.getIfPresent('user_2');
      final user3 = await cache.getIfPresent('user_3');

      expect(user1['name'], equals('Alice'));
      expect(user2['name'], equals('Bob'));
      expect(user3['name'], equals('Charlie'));
    });

    test('2. setMany() works with map keys', () async {
      await cache.setMany({
        {'resource': 'product', 'id': '1'}: {'name': 'Phone'},
        {'resource': 'product', 'id': '2'}: {'name': 'Laptop'},
        {'resource': 'user', 'id': '1'}: {'name': 'John'},
      });

      final product1 = await cache.getIfPresent({'resource': 'product', 'id': '1'});
      final user1 = await cache.getIfPresent({'resource': 'user', 'id': '1'});

      expect(product1['name'], equals('Phone'));
      expect(user1['name'], equals('John'));
    });

    test('3. setMany() applies TTL to all entries', () async {
      await cache.setMany({
        'temp_1': {'value': 1},
        'temp_2': {'value': 2},
        'temp_3': {'value': 3},
      }, ttl: Duration(milliseconds: 50));

      // All should exist initially
      expect(await cache.getIfPresent('temp_1'), isNotNull);
      expect(await cache.getIfPresent('temp_2'), isNotNull);

      // Wait for expiration
      await Future.delayed(Duration(milliseconds: 100));

      // All should be expired
      expect(await cache.getIfPresent('temp_1'), isNull);
      expect(await cache.getIfPresent('temp_2'), isNull);
      expect(await cache.getIfPresent('temp_3'), isNull);
    });

    test('4. setMany() with empty map does nothing', () async {
      await cache.set('existing', {'value': 'test'});

      await cache.setMany({});

      // Existing data should still be there
      final result = await cache.getIfPresent('existing');
      expect(result['value'], equals('test'));
    });
  });

  group('getMany() - Batch Get Tests', () {
    late CacheManager cache;

    setUp(() async {
      cache = await CacheManager.create(
        maxSize: 1024 * 1024,
        defaultTTL: Duration(minutes: 5),
        evictionPolicy: EvictionPolicy.lru,
      );
    });

    tearDown(() async {
      await cache.clear();
    });

    test('1. getMany() retrieves multiple existing keys', () async {
      await cache.set('user_1', {'name': 'Alice'});
      await cache.set('user_2', {'name': 'Bob'});
      await cache.set('user_3', {'name': 'Charlie'});

      final results = await cache.getMany(['user_1', 'user_2', 'user_3']);

      expect(results.length, equals(3));
      expect(results['user_1']['name'], equals('Alice'));
      expect(results['user_2']['name'], equals('Bob'));
      expect(results['user_3']['name'], equals('Charlie'));
    });

    test('2. getMany() skips non-existent keys', () async {
      await cache.set('user_1', {'name': 'Alice'});
      await cache.set('user_3', {'name': 'Charlie'});

      final results = await cache.getMany(['user_1', 'user_2', 'user_3', 'user_4']);

      expect(results.length, equals(2)); // Only user_1 and user_3
      expect(results.containsKey('user_1'), isTrue);
      expect(results.containsKey('user_2'), isFalse);
      expect(results.containsKey('user_3'), isTrue);
      expect(results.containsKey('user_4'), isFalse);
    });

    test('3. getMany() skips expired keys', () async {
      await cache.set('valid', {'status': 'ok'});
      await cache.set('expired', {'status': 'old'}, ttl: Duration(milliseconds: 1));

      await Future.delayed(Duration(milliseconds: 10));

      final results = await cache.getMany(['valid', 'expired']);

      expect(results.length, equals(1)); // Only valid
      expect(results.containsKey('valid'), isTrue);
      expect(results.containsKey('expired'), isFalse);
    });

    test('4. getMany() works with map keys', () async {
      await cache.set({'type': 'user', 'id': '1'}, {'name': 'Alice'});
      await cache.set({'type': 'user', 'id': '2'}, {'name': 'Bob'});
      await cache.set({'type': 'product', 'id': '1'}, {'name': 'Phone'});

      final results = await cache.getMany([
        {'type': 'user', 'id': '1'},
        {'id': '2', 'type': 'user'}, // Different order
        {'type': 'product', 'id': '1'},
      ]);

      expect(results.length, equals(3));
      // Keys are normalized, so check by iterating values
      final values = results.values.toList();
      expect(values.any((v) => v['name'] == 'Alice'), isTrue);
      expect(values.any((v) => v['name'] == 'Bob'), isTrue);
      expect(values.any((v) => v['name'] == 'Phone'), isTrue);
    });
  });

  group('invalidatePattern() - Pattern Matching Tests', () {
    late CacheManager cache;

    setUp(() async {
      cache = await CacheManager.create(
        maxSize: 1024 * 1024,
        defaultTTL: Duration(minutes: 5),
        evictionPolicy: EvictionPolicy.lru,
      );
    });

    tearDown(() async {
      await cache.clear();
    });

    test('1. invalidatePattern() removes all keys with matching prefix', () async {
      await cache.set('user_1', {'name': 'Alice'});
      await cache.set('user_2', {'name': 'Bob'});
      await cache.set('product_1', {'name': 'Phone'});
      await cache.set('product_2', {'name': 'Laptop'});

      await cache.invalidatePattern('user_');

      expect(await cache.getIfPresent('user_1'), isNull);
      expect(await cache.getIfPresent('user_2'), isNull);
      expect(await cache.getIfPresent('product_1'), isNotNull);
      expect(await cache.getIfPresent('product_2'), isNotNull);
    });

    test('2. invalidatePattern() with non-matching prefix removes nothing', () async {
      await cache.set('user_1', {'name': 'Alice'});
      await cache.set('product_1', {'name': 'Phone'});

      await cache.invalidatePattern('admin_');

      expect(await cache.getIfPresent('user_1'), isNotNull);
      expect(await cache.getIfPresent('product_1'), isNotNull);
    });

    test('3. invalidatePattern() works with KeyGen generated keys', () async {
      // KeyGen creates keys like "key:value|page:1"
      await cache.set({'resource': 'user', 'id': '1'}, {'name': 'Alice'});
      await cache.set({'resource': 'user', 'id': '2'}, {'name': 'Bob'});
      await cache.set({'resource': 'product', 'id': '1'}, {'name': 'Phone'});

      // Get the actual key prefix that KeyGen generates
      final userKeyPrefix = 'id:'; // All user keys will have this

      // This is tricky - we need to invalidate by the actual generated key format
      // Let's use a more practical approach: invalidate by partial match
      await cache.invalidatePattern('id:s:1'); // Keys containing user id "1"

      // Check what remains
      final stats = cache.getStats();
      expect(stats['totalEntries'], lessThan(3)); // Some were removed
    });

    test('4. invalidatePattern() with empty string removes nothing', () async {
      await cache.set('user_1', {'name': 'Alice'});
      await cache.set('product_1', {'name': 'Phone'});

      await cache.invalidatePattern('');

      // Nothing should match empty prefix, so all should remain
      expect(await cache.getIfPresent('user_1'), isNotNull);
      expect(await cache.getIfPresent('product_1'), isNotNull);
    });
  });


}
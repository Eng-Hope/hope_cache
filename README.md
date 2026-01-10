# Hope Dart Cache

Simple and fast caching for Dart/Flutter with TTL support, multiple eviction strategies, and pluggable storage.

[![pub package](https://img.shields.io/pub/v/hope_dart_cache.svg)](https://pub.dev/packages/hope_dart_cache)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

## Features

- **Multiple Eviction Policies** - LRU, LFU, FIFO
- **TTL Support** - Global default with per-key overrides
- **Map Keys** - React Query-style cache keys
- **Batch Operations** - Set/get multiple entries
- **Pattern Invalidation** - Clear groups by prefix
- **Pluggable Storage** - In-memory or custom backends
- **Zero Dependencies** - Pure Dart

## Installation

```bash
dart pub add hope_cache
```

## Quick Start

```dart
import 'package:hope_cache/cache_manager.dart';

final cache = await CacheManager.create(
  maxSize: 1024 * 1024,
  defaultTTL: Duration(minutes: 5),
  evictionPolicy: EvictionPolicy.lru,
);

await cache.set('user_123', {'name': 'Alice'});
final user = await cache.getIfPresent('user_123');
```

## Examples

### Basic Operations

```dart
final cache = await CacheManager.create(
  maxSize: 1024 * 1024,
  defaultTTL: Duration(minutes: 5),
  evictionPolicy: EvictionPolicy.lru,
);

// Store data
await cache.set('user_123', {'name': 'Alice', 'age': 30});
await cache.set('user_456', {'name': 'Bob', 'age': 25});

// Batch set
await cache.setMany({
  'product_1': {'name': 'Phone', 'price': 999},
  'product_2': {'name': 'Laptop', 'price': 1999},
});

// Get data
final user = await cache.getIfPresent('user_123');
final products = await cache.getMany(['product_1', 'product_2']);

// Get with fallback
final settings = await cache.get('app_settings', () async {
  return {'theme': 'dark', 'language': 'en'};
});

// Invalidate
await cache.invalidate('user_456');
await cache.invalidatePattern('product_');
await cache.clear();
```

### Map Keys

```dart
final cache = await CacheManager.create(
  maxSize: 1024 * 1024,
  defaultTTL: Duration(minutes: 5),
  evictionPolicy: EvictionPolicy.lru,
);

// Store with map key
await cache.set(
  {'resource': 'product', 'id': '123'},
  {'name': 'Laptop'},
);

// Different order = same key
final product = await cache.getIfPresent(
  {'id': '123', 'resource': 'product'},
);
```

### TTL Configuration

```dart
final cache = await CacheManager.create(
  maxSize: 1024 * 1024,
  defaultTTL: Duration(minutes: 5), // Default
  evictionPolicy: EvictionPolicy.lru,
);

// Uses default TTL
await cache.set('session', {'token': 'abc'});

// Custom TTL
await cache.set(
  'temp',
  {'value': 'expires soon'},
  ttl: Duration(seconds: 10),
);

await Future.delayed(Duration(seconds: 11));
print(await cache.getIfPresent('temp')); // null (expired)
print(await cache.getIfPresent('session')); // {...} (valid)
```

### Eviction Policies

```dart
// LRU - Evicts least recently accessed
final lruCache = await CacheManager.create(
  maxSize: 200,
  defaultTTL: Duration(hours: 1),
  evictionPolicy: EvictionPolicy.lru,
);

// LFU - Evicts least frequently accessed
final lfuCache = await CacheManager.create(
  maxSize: 200,
  defaultTTL: Duration(hours: 1),
  evictionPolicy: EvictionPolicy.lfu,
);

// FIFO - Evicts oldest entries
final fifoCache = await CacheManager.create(
  maxSize: 200,
  defaultTTL: Duration(hours: 1),
  evictionPolicy: EvictionPolicy.fifo,
);
```

### Custom Storage

```dart
class MyCustomStore implements CacheStore {
  final Map<String, String> _storage = {};

  @override
  Future<void> write(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<String?> read(String key) async => _storage[key];

  @override
  Future<void> delete(String key) async => _storage.remove(key);

  @override
  Future<void> clear() async => _storage.clear();

  @override
  Future<List<String>> getAllKeys() async => _storage.keys.toList();

  @override
  Future<int> getKeySize(String key) async => _storage[key]?.length ?? 0;

  @override
  Future<int> getTotalSize() async {
    int total = 0;
    for (final value in _storage.values) {
      total += value.length;
    }
    return total;
  }

  @override
  Future<Map<String, String>> getAllEntries() async => Map.from(_storage);
}

// Use custom storage
final cache = await CacheManager.create(
  maxSize: 1024 * 1024,
  defaultTTL: Duration(minutes: 5),
  evictionPolicy: EvictionPolicy.lru,
  storage: MyCustomStore(),
);
```

## API Reference

### CacheManager

**Creating**
```dart
CacheManager.create({
  required int maxSize,
  required Duration defaultTTL,
  required EvictionPolicy evictionPolicy,
  CacheStore? storage,
})
```

**Methods**
- `set(key, data, {Duration? ttl})` - Store data
- `get(key, fetcher, {Duration? ttl})` - Get with fallback
- `getIfPresent(key)` - Get if cached
- `has(key)` - Check existence
- `invalidate(key)` - Remove entry
- `clear()` - Remove all
- `setMany(Map entries, {Duration? ttl})` - Batch set
- `getMany(List keys)` - Batch get
- `invalidatePattern(String prefix)` - Remove by prefix
- `getStats()` - Get cache statistics

### KeyGen

- `KeyGen.fromMap(Map)` - Generate key from map
- `KeyGen.withPrefix(String, Map)` - Generate prefixed key

## License

Apache 2.0 - see [LICENSE](LICENSE) file.

## Author

**Hope Richard**  
📧 hoperichardmaleko@gmail.com  
🔗 [GitHub](https://github.com/Eng-Hope/hope_cache)
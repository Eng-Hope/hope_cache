
// Implement CacheStore interface;
import 'package:hope_cache/cache_manager.dart';
import 'package:hope_cache/cache_store.dart';

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

Future<void> main() async {
  final cache = await CacheManager.create(
    maxSize: 1024 * 1024,
    defaultTTL: Duration(minutes: 5),
    evictionPolicy: EvictionPolicy.lru,
    storage: MyCustomStore(),
  );

  await cache.set('key', 'value');
}
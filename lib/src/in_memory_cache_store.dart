
import 'cache_store.dart';

class InMemoryCacheStore implements CacheStore {
  final Map<String, String> _store = {};

  @override
  Future<void> write(String key, String serializedEntry) async {
    _store[key] = serializedEntry;
  }

  @override
  Future<String?> read(String key) async {
    return _store[key];
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }

  @override
  Future<List<String>> getAllKeys() async {
    return _store.keys.toList();
  }

  @override
  Future<int> getKeySize(String key) async {
    return _store[key]?.length ?? 0;
  }

  @override
  Future<int> getTotalSize() async {
    int total = 0;
    for (final value in _store.values) {
      total += value.length;
    }
    return total;
  }

  @override
  Future<Map<String, String>> getAllEntries() async {
    return Map.from(_store);
  }
}
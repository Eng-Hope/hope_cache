// lib/src/cache_store.dart

abstract class CacheStore {
  /// Writes a serialized cache entry string for the given key
  Future<void> write(String key, String serializedEntry);

  /// Reads a serialized cache entry string for the given key, returns null if not found
  Future<String?> read(String key);

  /// Deletes the cache entry for the given key
  Future<void> delete(String key);

  /// Clears all cache entries
  Future<void> clear();

  /// Returns all stored keys
  Future<List<String>> getAllKeys();

  /// Returns the size in bytes of a specific key, returns 0 if key doesn't exist
  Future<int> getKeySize(String key);

  /// Returns the current total size in bytes of all stored entries
  Future<int> getTotalSize();

  /// Returns all serialized entries currently in storage (for initialization)
  Future<Map<String, String>> getAllEntries();
}
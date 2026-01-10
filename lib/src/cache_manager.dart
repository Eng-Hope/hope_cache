// lib/src/cache_entry.dart
import 'dart:convert';

import 'cache_store.dart';
import 'cache_entry.dart';
import 'in_memory_cache_store.dart';
import 'key_gen.dart';

// lib/src/cache_manager.dart
enum EvictionPolicy {
  lru,  // Least Recently Used
  lfu,  // Least Frequently Used
  fifo, // First In First Out
}

class CacheManager {
  final int maxSize;
  final Duration defaultTTL;
  final EvictionPolicy evictionPolicy;
  final CacheStore storage;

  // Internal metadata tracking for eviction
  final Map<String, CacheEntry> _metadata = {};

  CacheManager._({
    required this.maxSize,
    required this.defaultTTL,
    required this.evictionPolicy,
    required this.storage,
  });

  static Future<CacheManager> create({
    required int maxSize,
    required Duration defaultTTL,
    required EvictionPolicy evictionPolicy,
    CacheStore? storage,
  }) async {
    final manager = CacheManager._(
      maxSize: maxSize,
      defaultTTL: defaultTTL,
      evictionPolicy: evictionPolicy,
      storage: storage ??
          InMemoryCacheStore(),
    );
    await manager._initialize();
    return manager;
  }

  /// Initialize cache from storage on startup
  Future<void> _initialize() async {
    final entries = await storage.getAllEntries();

    for (final entry in entries.entries) {
      try {
        final jsonMap = jsonDecode(entry.value) as Map<String, dynamic>;
        final cacheEntry = CacheEntry.fromJson(jsonMap);

        // Remove expired entries
        if (_isExpired(cacheEntry)) {
          await storage.delete(entry.key);
        } else {
          _metadata[entry.key] = cacheEntry;
        }
      } catch (e) {
        // Invalid entry, remove it
        await storage.delete(entry.key);
      }
    }
  }

  /// Check if entry is expired based on TTL (uses per-key TTL or default)
  bool _isExpired(CacheEntry entry) {
    final effectiveTTL = entry.ttl ?? defaultTTL;
    final expiryTime = entry.timestamp.add(effectiveTTL);
    return DateTime.now().isAfter(expiryTime);
  }

  /// Normalize key to string (handles both String and Map)
  String _normalizeKey(dynamic key) {
    if (key is String) return key;
    if (key is Map<String, dynamic>) return KeyGen.fromMap(key);
    if (key is Map) return KeyGen.fromMap(key.cast<String, dynamic>());
    throw ArgumentError(
        'Key must be either String or Map<String, dynamic>, got ${key.runtimeType}'
    );
  }

  /// Get data from cache or fetch fresh
  /// Key can be a String or Map<String, dynamic (like React Query)
  /// Users must handle serialization/deserialization themselves
  Future<dynamic> get(
      dynamic key,
      Future<dynamic> Function() fetcher, {
        Duration? ttl,
      }) async {
    final normalizedKey = _normalizeKey(key);
    final entry = _metadata[normalizedKey];

    // Cache hit - return if not expired
    if (entry != null && !_isExpired(entry)) {
      // Update access metadata
      final updatedEntry = entry.copyWith(
        lastAccessTime: DateTime.now(),
        accessCount: entry.accessCount + 1,
      );
      _metadata[normalizedKey] = updatedEntry;
      await storage.write(normalizedKey, jsonEncode(updatedEntry.toJson()));

      // Return cached data directly (user handles deserialization)
      return entry.data;
    }

    // Cache miss - fetch fresh data
    final freshData = await fetcher();
    await set(key, freshData, ttl: ttl);
    return freshData;
  }

  /// Manually set data in cache
  /// Key can be a String or Map<String, dynamic (like React Query)
  /// Users must pass already serialized/prepared data
  Future<void> set(dynamic key, dynamic data, {Duration? ttl}) async {
    final normalizedKey = _normalizeKey(key);

    // Calculate size based on JSON string representation
    final size = _calculateSize(data);

    // Check if eviction needed
    await _evictIfNeeded(size);

    // Create cache entry
    final now = DateTime.now();
    final entry = CacheEntry(
      data: data,
      timestamp: now,
      lastAccessTime: now,
      accessCount: 1,
      sizeInBytes: size,
      ttl: ttl, // Store per-key TTL
    );

    // Store in cache
    _metadata[normalizedKey] = entry;
    await storage.write(normalizedKey, jsonEncode(entry.toJson()));
  }

  /// Calculate size of data in bytes (approximation)
  int _calculateSize(dynamic data) {
    if (data == null) return 0;
    try {
      final jsonString = jsonEncode(data);
      return jsonString.length;
    } catch (e) {
      // If encoding fails, user's problem - but we still need a size
      // Use string representation as fallback
      return data.toString().length;
    }
  }

  /// Check if a key exists in cache (without fetching or checking expiration)
  bool has(dynamic key) {
    final normalizedKey = _normalizeKey(key);
    return _metadata.containsKey(normalizedKey);
  }

  /// Get cached data if present and not expired, returns null otherwise
  /// Does NOT call fetcher - just returns what's in cache
  Future<dynamic> getIfPresent(dynamic key) async {
    final normalizedKey = _normalizeKey(key);
    final entry = _metadata[normalizedKey];

    if (entry != null && !_isExpired(entry)) {
      // Update access metadata
      final updatedEntry = entry.copyWith(
        lastAccessTime: DateTime.now(),
        accessCount: entry.accessCount + 1,
      );
      _metadata[normalizedKey] = updatedEntry;
      await storage.write(normalizedKey, jsonEncode(updatedEntry.toJson()));

      return entry.data;
    }

    return null;
  }

  /// Set multiple entries at once
  Future<void> setMany(Map<dynamic, dynamic> entries, {Duration? ttl}) async {
    for (final entry in entries.entries) {
      await set(entry.key, entry.value, ttl: ttl);
    }
  }

  /// Get multiple entries at once
  /// Returns a map of key -> data (only includes keys that exist and are not expired)
  Future<Map<String, dynamic>> getMany(List<dynamic> keys) async {
    final result = <String, dynamic>{};

    for (final key in keys) {
      final normalizedKey = _normalizeKey(key);
      final data = await getIfPresent(key);
      if (data != null) {
        result[normalizedKey] = data;
      }
    }

    return result;
  }

  /// Invalidate all keys matching a prefix pattern
  /// Example: invalidatePattern('user_') removes 'user_123', 'user_456', etc.
  Future<void> invalidatePattern(String prefix) async {
    // Empty prefix would match everything - don't allow it
    if (prefix.isEmpty) return;

    final keysToRemove = _metadata.keys
        .where((key) => key.startsWith(prefix))
        .toList();

    for (final key in keysToRemove) {
      _metadata.remove(key);
      await storage.delete(key);
    }
  }

  /// Invalidate a specific cache entry
  /// Key can be a String or Map<String, dynamic
  Future<void> invalidate(dynamic key) async {
    final normalizedKey = _normalizeKey(key);
    _metadata.remove(normalizedKey);
    await storage.delete(normalizedKey);
  }

  /// Clear all cache entries
  Future<void> clear() async {
    _metadata.clear();
    await storage.clear();
  }

  /// Evict entries if needed to make space
  Future<void> _evictIfNeeded(int newEntrySize) async {
    while ((await storage.getTotalSize()) + newEntrySize > maxSize &&
        _metadata.isNotEmpty) {
      final keyToEvict = _selectEvictionCandidate();
      if (keyToEvict != null) {
        await invalidate(keyToEvict);
      } else {
        break;
      }
    }
  }

  /// Select which key to evict based on policy
  String? _selectEvictionCandidate() {
    if (_metadata.isEmpty) return null;

    switch (evictionPolicy) {
      case EvictionPolicy.lru:
      // Find least recently used
        return _metadata.entries.reduce(
              (a, b) => a.value.lastAccessTime.isBefore(b.value.lastAccessTime) ? a : b,
        ).key;

      case EvictionPolicy.lfu:
      // Find least frequently used
        return _metadata.entries.reduce(
              (a, b) => a.value.accessCount < b.value.accessCount ? a : b,
        ).key;

      case EvictionPolicy.fifo:
      // Find oldest entry
        return _metadata.entries.reduce(
              (a, b) => a.value.timestamp.isBefore(b.value.timestamp) ? a : b,
        ).key;
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'totalEntries': _metadata.length,
      'totalSize': _metadata.values.fold<int>(
        0,
            (sum, entry) => sum + entry.sizeInBytes,
      ),
      'maxSize': maxSize,
      'evictionPolicy': evictionPolicy.toString(),
    };
  }
}

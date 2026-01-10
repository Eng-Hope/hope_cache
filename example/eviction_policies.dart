
import 'package:hope_cache/cache_manager.dart';

Future<void> main() async {
  // LRU — evicts the least recently accessed entry
  final lruCache = await CacheManager.create(
    maxSize: 200,
    defaultTTL: Duration(hours: 1),
    evictionPolicy: EvictionPolicy.lru,
  );

  // LFU — evicts the least frequently accessed entry
  final lfuCache = await CacheManager.create(
    maxSize: 200,
    defaultTTL: Duration(hours: 1),
    evictionPolicy: EvictionPolicy.lfu,
  );

  // FIFO — evicts the oldest inserted entry
  final fifoCache = await CacheManager.create(
    maxSize: 200,
    defaultTTL: Duration(hours: 1),
    evictionPolicy: EvictionPolicy.fifo,
  );

  // Add entries until eviction is triggered
  await lruCache.set('a', 'A');
  await lruCache.set('b', 'B');
  await lruCache.set('c', 'C');

  // Access one entry to affect eviction order
  await lruCache.getIfPresent('a');

  // Adding another entry may evict a different key
  await lruCache.set('d', 'D');

  print(lruCache.getStats());
}

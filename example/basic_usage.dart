import 'package:hope_cache/cache_manager.dart';
Future<void> main() async {
  final cache = await CacheManager.create(
    maxSize: 1024 * 1024,
    defaultTTL: Duration(minutes: 5),
    evictionPolicy: EvictionPolicy.lru,
  );

  // Store individual entries
  await cache.set('user_123', {'name': 'Alice', 'age': 30});
  await cache.set('user_456', {'name': 'Bob', 'age': 25});

  // Store multiple entries at once
  await cache.setMany({
    'product_1': {'name': 'Phone', 'price': 999},
    'product_2': {'name': 'Laptop', 'price': 1999},
  });

  // Read a single entry if present
  final user = await cache.getIfPresent('user_123');
  print(user);

  // Read multiple entries at once
  final products = await cache.getMany([
    'product_1',
    'product_2',
    'product_3', // ignored if not present
  ]);
  print(products);

  // Read with fallback fetcher
  final settings = await cache.get('app_settings', () async {
    return {'theme': 'dark', 'language': 'en'};
  });
  print(settings);

  // Invalidate a single entry
  await cache.invalidate('user_456');

  // Invalidate entries by prefix
  await cache.invalidatePattern('product_');

  // Clear all cached data
  await cache.clear();
}

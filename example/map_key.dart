
import 'package:hope_cache/src/cache_manager.dart';

Future<void> main() async {
  final cache = await CacheManager.create(
    maxSize: 1024 * 1024,
    defaultTTL: Duration(minutes: 5),
    evictionPolicy: EvictionPolicy.lru,
  );

  // Store using a Map key
  await cache.set(
    {'resource': 'product', 'id': '123'},
    {'name': 'Laptop'},
  );

  // Same key, different order
  final product = await cache.getIfPresent(
    {'id': '123', 'resource': 'product'},
  );

  print(product); // {name: Laptop}
}

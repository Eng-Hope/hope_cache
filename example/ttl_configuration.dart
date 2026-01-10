
import 'package:hope_cache/src/cache_manager.dart';

Future<void> main() async {
  final cache = await CacheManager.create(
    maxSize: 1024 * 1024,
    defaultTTL: Duration(minutes: 5), // Default for all keys
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
  print('Temp (expired): ${await cache.getIfPresent('temp')}');
  print('Session (valid): ${await cache.getIfPresent('session')}');
}
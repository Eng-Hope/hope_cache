// lib/src/key_gen.dart
/// Utility class for generating consistent cache keys
class KeyGen {
  /// Generate a deterministic key from a map by sorting keys
  ///
  /// Example:
  /// ```dart
  /// final key = KeyGen.fromMap({
  ///   "key": "product",
  ///   "page": "1",
  ///   "size": "2"
  /// });
  /// // Result: "key:product|page:1|size:2"
  /// ```
  static String fromMap(Map<String, dynamic> params) {
    if (params.isEmpty) return '';

    // Sort keys alphabetically for consistency
    final sortedKeys = params.keys.toList()..sort();

    // Build key from sorted key-value pairs
    final parts = sortedKeys.map((key) {
      final value = params[key];
      return '$key:${_normalizeValue(value)}';
    });

    return parts.join('|');
  }

  /// Generate a key with a prefix
  ///
  /// Example:
  /// ```dart
  /// final key = KeyGen.withPrefix('user', {'id': '123', 'type': 'admin'});
  /// // Result: "user:id:123|type:admin"
  /// ```
  static String withPrefix(String prefix, Map<String, dynamic> params) {
    final mapKey = fromMap(params);
    return mapKey.isEmpty ? prefix : '$prefix:$mapKey';
  }

  /// Normalize values for consistent string representation
  /// Uses type prefixes to distinguish between different types with same string value
  static String _normalizeValue(dynamic value) {
    if (value == null) return 'null:';
    if (value is String) return 's:$value';  // s: prefix for strings
    if (value is int) return 'i:$value';     // i: prefix for ints
    if (value is double) return 'd:$value';  // d: prefix for doubles
    if (value is bool) return 'b:$value';    // b: prefix for bools
    if (value is List) return 'l:[${value.map(_normalizeValue).join(',')}]';
    if (value is Map) return 'm:{${fromMap(value.cast<String, dynamic>())}}';
    return 'o:${value.toString()}';  // o: prefix for other objects
  }
}

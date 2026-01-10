class CacheEntry {
  final dynamic data; // Changed from Object? to dynamic
  final DateTime timestamp;
  final DateTime lastAccessTime;
  final int accessCount;
  final int sizeInBytes;
  final Duration? ttl; // Optional per-key TTL

  CacheEntry({
    required this.data,
    required this.timestamp,
    required this.lastAccessTime,
    required this.accessCount,
    required this.sizeInBytes,
    this.ttl,
  });

  /// Serialize CacheEntry to JSON Map
  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'lastAccessTime': lastAccessTime.toIso8601String(),
      'accessCount': accessCount,
      'sizeInBytes': sizeInBytes,
      'ttl': ttl?.inMilliseconds,
    };
  }

  /// Deserialize CacheEntry from JSON Map
  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      data: json['data'],
      timestamp: DateTime.parse(json['timestamp']),
      lastAccessTime: DateTime.parse(json['lastAccessTime']),
      accessCount: json['accessCount'],
      sizeInBytes: json['sizeInBytes'],
      ttl: json['ttl'] != null ? Duration(milliseconds: json['ttl']) : null,
    );
  }

  /// Create a copy with updated fields
  CacheEntry copyWith({
    dynamic data,
    DateTime? timestamp,
    DateTime? lastAccessTime,
    int? accessCount,
    int? sizeInBytes,
    Duration? ttl,
  }) {
    return CacheEntry(
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      lastAccessTime: lastAccessTime ?? this.lastAccessTime,
      accessCount: accessCount ?? this.accessCount,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
      ttl: ttl ?? this.ttl,
    );
  }
}

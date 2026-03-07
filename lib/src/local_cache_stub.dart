import 'local_cache_base.dart';

class _MemoryLocalCache implements LocalCache {
  Map<String, dynamic>? _data;

  @override
  Future<void> clear() async {
    _data = null;
  }

  @override
  Future<Map<String, dynamic>?> readJson() async => _data;

  @override
  Future<void> writeJson(Map<String, dynamic> data) async {
    _data = Map<String, dynamic>.from(data);
  }
}

LocalCache createPlatformLocalCache() => _MemoryLocalCache();

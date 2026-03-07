abstract class LocalCache {
  Future<Map<String, dynamic>?> readJson();

  Future<void> writeJson(Map<String, dynamic> data);

  Future<void> clear();
}

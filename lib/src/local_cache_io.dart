import 'dart:convert';
import 'dart:io';

import 'local_cache_base.dart';

class _IoLocalCache implements LocalCache {
  _IoLocalCache() : _file = File('${Directory.systemTemp.path}/goal_lock.json');

  final File _file;

  @override
  Future<void> clear() async {
    if (await _file.exists()) {
      await _file.delete();
    }
  }

  @override
  Future<Map<String, dynamic>?> readJson() async {
    if (!await _file.exists()) {
      return null;
    }

    final raw = await _file.readAsString();
    if (raw.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    return null;
  }

  @override
  Future<void> writeJson(Map<String, dynamic> data) async {
    await _file.writeAsString(jsonEncode(data));
  }
}

LocalCache createPlatformLocalCache() => _IoLocalCache();

import 'local_cache_base.dart';
import 'local_cache_stub.dart'
    if (dart.library.io) 'local_cache_io.dart'
    as platform;

LocalCache createLocalCache() => platform.createPlatformLocalCache();

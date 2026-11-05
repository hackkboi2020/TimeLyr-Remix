import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Remembers songs for which no TTML was found, so the app does not hit the
/// lyrics servers again every time a song is opened or "download all" runs.
/// Entries expire after a week.
class TtmlMissCache {
  static const String _key = 'ttml_miss_cache_v1';
  static const Duration _ttl = Duration(days: 7);

  static Future<Map<String, int>>? _loading;
  static Map<String, int> _cache = {};
  static Timer? _persistTimer;

  static Future<Map<String, int>> _load() {
    return _loading ??= _doLoad();
  }

  static Future<Map<String, int>> _doLoad() async {
    final map = <String, int>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            if (k is String && v is num) {
              map[k] = v.toInt();
            }
          });
        }
      }
    } catch (_) {}
    _cache = map;
    return map;
  }

  static void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(seconds: 2), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_key, jsonEncode(_cache));
      } catch (_) {}
    });
  }

  static Future<bool> isMiss(String songPath) async {
    final map = await _load();
    final stamp = map[songPath];
    if (stamp == null) {
      return false;
    }
    final age = DateTime.now().millisecondsSinceEpoch - stamp;
    if (age > _ttl.inMilliseconds) {
      map.remove(songPath);
      _schedulePersist();
      return false;
    }
    return true;
  }

  static Future<void> recordMiss(String songPath) async {
    final map = await _load();
    map[songPath] = DateTime.now().millisecondsSinceEpoch;
    _schedulePersist();
  }

  static Future<void> clear(String songPath) async {
    final map = await _load();
    if (map.remove(songPath) != null) {
      _schedulePersist();
    }
  }

  static Future<void> clearAll() async {
    final map = await _load();
    map.clear();
    _schedulePersist();
  }
}

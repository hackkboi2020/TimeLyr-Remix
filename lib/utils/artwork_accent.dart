import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Picks an accent color from album artwork, the way Mornye colors its player.
class ArtworkAccent {
  static final Map<String, Color?> _cache = {};

  /// Accent color for a cover, cached by [key] (the song path). Null when the
  /// image can't be read.
  static Future<Color?> fromBytes(String key, Uint8List bytes) async {
    if (_cache.containsKey(key)) return _cache[key];
    try {
      final scheme = await ColorScheme.fromImageProvider(
        provider: MemoryImage(bytes),
        brightness: Brightness.dark,
      );
      _cache[key] = scheme.primary;
    } catch (_) {
      _cache[key] = null;
    }
    return _cache[key];
  }
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small view options that screens listen to (More → Folder filter).
class ViewSettings {
  static const String _folderFilterKey = 'folder_filter_enabled';
  static const String _artworkAccentKey = 'artwork_accent_enabled';

  /// Whether the Library shows the folder filter chip.
  static final ValueNotifier<bool> folderFilter = ValueNotifier<bool>(false);

  /// Whether the lyrics screen takes its accent color from the album artwork.
  static final ValueNotifier<bool> artworkAccent = ValueNotifier<bool>(true);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      folderFilter.value = prefs.getBool(_folderFilterKey) ?? false;
      artworkAccent.value = prefs.getBool(_artworkAccentKey) ?? true;
    } catch (_) {}
  }

  static Future<void> setFolderFilter(bool enabled) async {
    folderFilter.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_folderFilterKey, enabled);
    } catch (_) {}
  }

  static Future<void> setArtworkAccent(bool enabled) async {
    artworkAccent.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_artworkAccentKey, enabled);
    } catch (_) {}
  }
}

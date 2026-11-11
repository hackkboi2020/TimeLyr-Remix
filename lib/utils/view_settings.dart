import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small view options that screens listen to (More screen).
class ViewSettings {
  static const String _folderViewKey = 'folder_view_enabled';
  static const String _artworkAccentKey = 'artwork_accent_enabled';
  static const String _statusTagsKey = 'status_tags_enabled';
  static const String _excludedKey = 'excluded_folders';

  /// Browse the Library as folders and subfolders instead of one flat list.
  static final ValueNotifier<bool> folderView = ValueNotifier<bool>(false);

  /// Whether the lyrics screen takes its accent color from the album artwork.
  static final ValueNotifier<bool> artworkAccent = ValueNotifier<bool>(true);

  /// Show the Word-synced / Line-synced / Not downloaded tag on each song.
  static final ValueNotifier<bool> statusTags = ValueNotifier<bool>(true);

  /// Folders hidden from the Library (their subfolders too).
  static final ValueNotifier<Set<String>> excludedFolders =
      ValueNotifier<Set<String>>(<String>{});

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      folderView.value = prefs.getBool(_folderViewKey) ?? false;
      artworkAccent.value = prefs.getBool(_artworkAccentKey) ?? true;
      statusTags.value = prefs.getBool(_statusTagsKey) ?? true;
      excludedFolders.value = (prefs.getStringList(_excludedKey) ?? const []).toSet();
    } catch (_) {}
  }

  static Future<void> _saveBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  static Future<void> setFolderView(bool enabled) async {
    folderView.value = enabled;
    await _saveBool(_folderViewKey, enabled);
  }

  static Future<void> setArtworkAccent(bool enabled) async {
    artworkAccent.value = enabled;
    await _saveBool(_artworkAccentKey, enabled);
  }

  static Future<void> setStatusTags(bool enabled) async {
    statusTags.value = enabled;
    await _saveBool(_statusTagsKey, enabled);
  }

  static Future<void> setExcludedFolders(Set<String> folders) async {
    excludedFolders.value = Set<String>.of(folders);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_excludedKey, folders.toList());
    } catch (_) {}
  }
}

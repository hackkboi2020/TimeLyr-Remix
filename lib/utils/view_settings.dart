import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small view options that screens listen to (More → Folder filter).
class ViewSettings {
  static const String _folderFilterKey = 'folder_filter_enabled';

  /// Whether the Library shows the folder filter chip.
  static final ValueNotifier<bool> folderFilter = ValueNotifier<bool>(false);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      folderFilter.value = prefs.getBool(_folderFilterKey) ?? false;
    } catch (_) {}
  }

  static Future<void> setFolderFilter(bool enabled) async {
    folderFilter.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_folderFilterKey, enabled);
    } catch (_) {}
  }
}

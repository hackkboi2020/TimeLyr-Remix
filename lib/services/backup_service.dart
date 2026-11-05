import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../theme/app_theme.dart';
import '../utils/app_storage.dart';
import 'file_service.dart';
import 'notifications_settings.dart';

String _encodeJson(Map<String, dynamic> data) => jsonEncode(data);

Map<String, dynamic> _decodeJson(String text) =>
    jsonDecode(text) as Map<String, dynamic>;

class BackupFormatException implements Exception {
  final String message;
  const BackupFormatException(this.message);

  @override
  String toString() => message;
}

class ExportResult {
  final int lyricsCount;
  const ExportResult(this.lyricsCount);
}

class ImportResult {
  final int restored;
  final int skipped;
  final int missing;
  const ImportResult({
    required this.restored,
    required this.skipped,
    required this.missing,
  });
}

/// Exports/imports app settings and downloaded lyrics (.lrc / .ttml) as a
/// single JSON file. Lyrics are keyed by their path relative to the music
/// folder, so a backup can be restored on another device.
class BackupService {
  static const String _appId = 'TimeLyr';
  static const int _version = 1;
  static const List<String> _lyricExtensions = ['.lrc', '.ttml'];

  static String _keyFor(String filePath, String? root) {
    if (root != null && p.isWithin(root, filePath)) {
      return p.relative(filePath, from: root).replaceAll('\\', '/');
    }
    return p.basename(filePath);
  }

  /// Maps backup key -> absolute lyric file path for every song in the library.
  static Future<Map<String, String>> _lyricTargets() async {
    final root = await AppStorage.loadFolder();
    final normalizedRoot = root == null ? null : p.normalize(root);
    final targets = <String, String>{};
    for (final song in FileService.librarySongs) {
      final dir = p.dirname(song.path);
      final name = p.basenameWithoutExtension(song.path);
      for (final ext in _lyricExtensions) {
        final path = p.join(dir, '$name$ext');
        targets[_keyFor(path, normalizedRoot)] = path;
      }
    }
    return targets;
  }

  /// Returns null if the user cancels the save dialog.
  static Future<ExportResult?> exportBackup() async {
    final targets = await _lyricTargets();

    final lyrics = <String, String>{};
    for (final entry in targets.entries) {
      final file = File(entry.value);
      try {
        if (await file.exists()) {
          lyrics[entry.key] = await file.readAsString();
        }
      } catch (_) {
        // Skip unreadable files.
      }
    }

    final data = <String, dynamic>{
      'app': _appId,
      'version': _version,
      'created': DateTime.now().toIso8601String(),
      'settings': {
        AppStorage.watcherEnabledKey: await AppStorage.loadWatcherEnabled(),
        'notifications_enabled': await NotificationSettings.isEnabled(),
        'theme': AppTheme.current.id,
      },
      'lyrics': lyrics,
    };

    final json = await compute(_encodeJson, data);
    final bytes = Uint8List.fromList(utf8.encode(json));

    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final fileName =
        'timelyr_backup_${now.year}${two(now.month)}${two(now.day)}.json';

    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save TimeLyr backup',
      fileName: fileName,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (savedPath == null) {
      return null;
    }
    return ExportResult(lyrics.length);
  }

  /// Returns null if the user cancels the file picker.
  static Future<ImportResult?> importBackup() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return null;
    }

    final picked0 = picked.files.single;
    Uint8List? bytes = picked0.bytes;
    if (bytes == null && picked0.path != null) {
      bytes = await File(picked0.path!).readAsBytes();
    }
    if (bytes == null) {
      throw const BackupFormatException('Could not read the selected file.');
    }

    final Map<String, dynamic> data;
    try {
      data = await compute(_decodeJson, utf8.decode(bytes));
    } catch (_) {
      throw const BackupFormatException('That file is not a valid TimeLyr backup.');
    }
    if (data['app'] != _appId || data['lyrics'] is! Map) {
      throw const BackupFormatException('That file is not a valid TimeLyr backup.');
    }

    // Settings
    final settings = data['settings'];
    if (settings is Map) {
      final watcher = settings[AppStorage.watcherEnabledKey];
      if (watcher is bool) {
        await AppStorage.saveWatcherEnabled(watcher);
      }
      final notifications = settings['notifications_enabled'];
      if (notifications is bool) {
        await NotificationSettings.setEnabled(notifications);
      }
      final theme = settings['theme'];
      if (theme is String) {
        await AppTheme.setPreset(theme);
      }
    }

    // Lyrics: only restore for songs that exist in this library, and never
    // overwrite lyric files that are already there.
    final targets = await _lyricTargets();
    final lyrics = (data['lyrics'] as Map).cast<String, dynamic>();
    int restored = 0;
    int skipped = 0;
    int missing = 0;

    for (final entry in lyrics.entries) {
      final target = targets[entry.key];
      final content = entry.value;
      if (target == null || content is! String) {
        missing++;
        continue;
      }
      final file = File(target);
      if (await file.exists()) {
        skipped++;
        continue;
      }
      try {
        await file.writeAsString(content);
        restored++;
      } catch (_) {
        missing++;
      }
    }

    FileService.libraryUpdateController.add(null);
    return ImportResult(restored: restored, skipped: skipped, missing: missing);
  }
}

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:timelyr/models/song.dart';
import 'package:timelyr/services/file_service.dart';
import 'package:timelyr/theme/app_theme.dart';
import 'package:timelyr/utils/view_settings.dart';

/// A folder that contains songs (directly or in subfolders).
class FolderNode {
  final String path;
  final String name;
  final int depth;
  final int count;

  const FolderNode({
    required this.path,
    required this.name,
    required this.depth,
    required this.count,
  });
}

class FolderIndex {
  static String? _dir(Song song) {
    final d = p.dirname(song.path);
    return d.isEmpty || d == '.' ? null : d;
  }

  /// The longest folder that contains every song ('' when unknown).
  static String rootOf(List<Song> songs) {
    final dirs = songs.map(_dir).whereType<String>().toList();
    if (dirs.isEmpty) return '';
    var prefix = dirs.first;
    for (final dir in dirs) {
      while (!(dir == prefix || dir.startsWith('$prefix/'))) {
        final parent = p.dirname(prefix);
        if (parent == prefix || parent == '.' || parent.isEmpty) return '';
        prefix = parent;
      }
    }
    return prefix;
  }

  /// Immediate subfolders of [dir] that hold songs, with recursive counts.
  static List<FolderNode> children(List<Song> songs, String dir) {
    final counts = <String, int>{};
    final prefix = '$dir/';
    for (final song in songs) {
      final d = _dir(song);
      if (d == null || !d.startsWith(prefix)) continue;
      final child = prefix + d.substring(prefix.length).split('/').first;
      counts[child] = (counts[child] ?? 0) + 1;
    }
    final paths = counts.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      for (final path in paths)
        FolderNode(path: path, name: p.basename(path), depth: 0, count: counts[path]!),
    ];
  }

  /// Every folder that holds songs (parents first) with recursive counts.
  static List<FolderNode> all(List<Song> songs) {
    final root = rootOf(songs);
    final counts = <String, int>{};
    for (final song in songs) {
      var current = _dir(song);
      while (current != null && current.length > root.length && current.startsWith(root)) {
        counts[current] = (counts[current] ?? 0) + 1;
        final parent = p.dirname(current);
        current = parent == current ? null : parent;
      }
    }
    final paths = counts.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      for (final path in paths)
        FolderNode(
          path: path,
          name: p.basename(path),
          depth: _depthOf(path, root),
          count: counts[path]!,
        ),
    ];
  }

  static int _depthOf(String path, String root) {
    var rest = path.length > root.length ? path.substring(root.length) : '';
    rest = rest.replaceAll(RegExp(r'^/+|/+$'), '');
    return rest.isEmpty ? 0 : '/'.allMatches(rest).length;
  }

  static bool isExcluded(String songPath, Set<String> excluded) {
    if (excluded.isEmpty) return false;
    for (final folder in excluded) {
      if (songPath.startsWith('$folder/')) return true;
    }
    return false;
  }
}

/// Lets the user pick folders to hide from the Library.
Future<void> showExcludedFoldersDialog(BuildContext context) {
  final nodes = FolderIndex.all(FileService.librarySongs);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return ValueListenableBuilder<Set<String>>(
        valueListenable: ViewSettings.excludedFolders,
        builder: (context, excluded, _) {
          return AlertDialog(
            backgroundColor: AppTheme.background,
            title: const Text(
              'Hide folders',
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: nodes.isEmpty
                  ? const Text(
                      'No songs in the Library yet.',
                      style: TextStyle(color: Colors.white70),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final node in nodes)
                          Builder(
                            builder: (context) {
                              final coveredByParent = excluded.any(
                                (e) => node.path.startsWith('$e/'),
                              );
                              final checked =
                                  coveredByParent || excluded.contains(node.path);
                              return Padding(
                                padding: EdgeInsets.only(left: node.depth * 16.0),
                                child: CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  activeColor: AppTheme.accent,
                                  checkColor: Colors.white,
                                  value: checked,
                                  onChanged: coveredByParent
                                      ? null
                                      : (value) {
                                          final next = Set<String>.of(excluded);
                                          if (value == true) {
                                            next.add(node.path);
                                          } else {
                                            next.remove(node.path);
                                          }
                                          ViewSettings.setExcludedFolders(next);
                                        },
                                  title: Text(
                                    '${node.name} (${node.count})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:timelyr/models/song.dart';
import 'package:timelyr/theme/app_theme.dart';

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
  /// Every folder with songs under the common root, with recursive song
  /// counts. Parents come before their children.
  static List<FolderNode> build(List<Song> songs) {
    final dirs = songs
        .map((s) => p.dirname(s.path))
        .where((d) => d.isNotEmpty && d != '.')
        .toList();
    if (dirs.isEmpty) return const [];

    final root = _commonDir(dirs);
    final counts = <String, int>{};
    for (final dir in dirs) {
      var current = dir;
      while (current.length > root.length && current.startsWith(root)) {
        counts[current] = (counts[current] ?? 0) + 1;
        final parent = p.dirname(current);
        if (parent == current) break;
        current = parent;
      }
    }

    final paths = counts.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      for (final path in paths)
        FolderNode(
          path: path,
          name: p.basename(path),
          depth: _depth(path, root),
          count: counts[path]!,
        ),
    ];
  }

  static int _depth(String path, String root) {
    var rest = path.length > root.length ? path.substring(root.length) : '';
    rest = rest.replaceAll(RegExp(r'^/+|/+$'), '');
    return rest.isEmpty ? 0 : '/'.allMatches(rest).length;
  }

  static String _commonDir(List<String> dirs) {
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

  static bool contains(String folder, String songPath) =>
      songPath.startsWith('$folder/');
}

/// Chip that shows the active folder filter; tapping opens the folder list.
class FolderFilterBar extends StatelessWidget {
  final List<Song> songs;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const FolderFilterBar({
    super.key,
    required this.songs,
    required this.selected,
    required this.onChanged,
  });

  Future<void> _openList(BuildContext context, List<FolderNode> nodes) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        Widget row(String label, int depth, bool isSelected, String? value) {
          return InkWell(
            onTap: () {
              onChanged(value);
              Navigator.of(dialogContext).pop();
            },
            child: Padding(
              padding: EdgeInsets.only(
                left: depth * 16.0,
                top: 10,
                bottom: 10,
                right: 8,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? AppTheme.accent : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }

        return AlertDialog(
          backgroundColor: AppTheme.background,
          title: const Text('Folders', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                row('All folders (${songs.length})', 0, selected == null, null),
                for (final node in nodes)
                  row(
                    '${node.name} (${node.count})',
                    node.depth + 1,
                    selected == node.path,
                    node.path,
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
  }

  @override
  Widget build(BuildContext context) {
    final nodes = FolderIndex.build(songs);
    if (nodes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          ActionChip(
            avatar: const Icon(Icons.folder, size: 18, color: Colors.white),
            label: Text(
              selected == null ? 'All folders' : p.basename(selected!),
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            side: BorderSide.none,
            onPressed: () => _openList(context, nodes),
          ),
          if (selected != null)
            IconButton(
              tooltip: 'Show all folders',
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => onChanged(null),
            ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timelyr/screens/about_screen.dart';
import 'package:timelyr/services/file_service.dart';
import 'package:timelyr/services/lyrics_service.dart';
import 'package:timelyr/widgets/scan_music.dart';
import 'package:timelyr/widgets/select_directory.dart';
import '../services/backup_service.dart';
import '../utils/view_settings.dart';
import '../widgets/color_picker_dialog.dart';
import '../utils/ttml_miss_cache.dart';
import '../services/notifications_settings.dart';
import '../utils/app_storage.dart';
import 'package:timelyr/theme/app_theme.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool notificationsEnable = true;
  bool watcherEnabled = true;

  @override
  void initState() {
    super.initState();
    enableNotifications();
    loadWatcherPref();
  }

  void enableNotifications() async {
    notificationsEnable = await NotificationSettings.isEnabled();
    setState(() {});
  }

  void loadWatcherPref() async {
    watcherEnabled = await AppStorage.loadWatcherEnabled();
    setState(() {});
  }

  Future<void> _pickAccent(VoidCallback refresh) async {
    final picked = await showColorPickerDialog(
      context,
      initial: AppTheme.accent,
      title: 'Accent color',
    );
    if (picked != null) {
      await AppTheme.setAccentOverride(picked);
      refresh();
    }
  }

  Future<void> _editCustomTheme(VoidCallback refresh) async {
    final base = AppTheme.custom ?? AppTheme.current;
    var accent = base.accent;
    var background = base.background;
    var cards = base.backgroundAlt;
    final gradient = List<Color>.of(base.gradient);
    while (gradient.length < 3) {
      gradient.add(gradient.last);
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setInner) {
            Widget swatch(String label, Color color, ValueChanged<Color> set) {
              return ListTile(
                dense: true,
                leading: CircleAvatar(backgroundColor: color, radius: 14),
                title: Text(label, style: const TextStyle(color: Colors.white)),
                onTap: () async {
                  final picked = await showColorPickerDialog(
                    innerContext,
                    initial: color,
                    title: label,
                  );
                  if (picked != null) {
                    setInner(() => set(picked));
                  }
                },
              );
            }

            return AlertDialog(
              backgroundColor: AppTheme.background,
              title: const Text(
                'Custom theme',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Preview',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    swatch('Accent', accent, (c) => accent = c),
                    swatch('Background', background, (c) => background = c),
                    swatch('Cards', cards, (c) => cards = c),
                    swatch('Gradient start', gradient[0], (c) => gradient[0] = c),
                    swatch('Gradient middle', gradient[1], (c) => gradient[1] = c),
                    swatch('Gradient end', gradient[2], (c) => gradient[2] = c),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                  ),
                  onPressed: () async {
                    await AppTheme.saveCustom(
                      background: background,
                      backgroundAlt: cards,
                      accent: accent,
                      gradient: List<Color>.of(gradient),
                    );
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    refresh();
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showThemeDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void refresh() {
              setDialogState(() {});
              if (mounted) {
                setState(() {});
              }
            }

            Widget presetTile(AppThemePreset preset) {
              return ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: preset.gradient),
                    border: Border.all(color: preset.accent, width: 3),
                  ),
                ),
                title: Text(
                  preset.name,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: AppTheme.current.id == preset.id
                    ? Icon(Icons.check, color: AppTheme.accent)
                    : null,
                onTap: () async {
                  await AppTheme.setPreset(preset.id);
                  refresh();
                },
              );
            }

            final custom = AppTheme.custom;
            return AlertDialog(
              backgroundColor: AppTheme.background,
              title: const Text('Theme', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.accent,
                        radius: 18,
                      ),
                      title: const Text(
                        'Accent color',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        AppTheme.accentOverride == null
                            ? 'Follows the theme'
                            : 'Custom',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                      trailing: AppTheme.accentOverride == null
                          ? null
                          : TextButton(
                              onPressed: () async {
                                await AppTheme.setAccentOverride(null);
                                refresh();
                              },
                              child: const Text(
                                'Reset',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                      onTap: () => _pickAccent(refresh),
                    ),
                    const Divider(color: Colors.white24),
                    for (final preset in AppTheme.presets) presetTile(preset),
                    if (custom != null) presetTile(custom),
                    ListTile(
                      leading: const Icon(Icons.tune, color: Colors.white),
                      title: Text(
                        custom == null
                            ? 'Create custom theme…'
                            : 'Edit custom theme…',
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () => _editCustomTheme(refresh),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await BackupService.exportBackup();
      if (result == null) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Backup saved (${result.lyricsCount} lyric files).'),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not create the backup.')),
      );
    }
  }

  Future<void> _importBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await BackupService.importBackup();
      if (result == null) {
        return;
      }
      enableNotifications();
      loadWatcherPref();
      if (mounted) {
        setState(() {});
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Restored ${result.restored} lyric files '
            '(${result.skipped} already existed, '
            '${result.missing} had no matching song).',
          ),
        ),
      );
    } on BackupFormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not import the backup.')),
      );
    }
  }

  void _fixBadLrcs(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        int fixed = 0;
        int total = 0;
        String currentSong = '';
        bool started = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (!started) {
              started = true;
              Future.microtask(() async {
                final result = await LyricsService.fixBadLrcFiles(
                  FileService.librarySongs,
                  onProgress: (i, totalSongs, title) {
                    setDialogState(() {
                      currentSong = title;
                    });
                  },
                );
                setDialogState(() {
                  fixed = result.fixed;
                  total = result.total;
                });
              });
            }

            return AlertDialog(
              backgroundColor: AppTheme.background,
              title: Text(
                total == 0 && fixed == 0 && currentSong.isEmpty
                    ? 'Searching for damaged LRC files...'
                    : total == 0 && fixed == 0
                    ? 'Repairing...'
                    : 'Repair complete',
                style: const TextStyle(color: Colors.white),
              ),
              content: total == 0 && fixed == 0
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LinearProgressIndicator(
                          color: AppTheme.accent,
                          backgroundColor: Colors.white24,
                        ),
                        if (currentSong.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            currentSong,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    )
                  : Text(
                      total > 0
                          ? 'Repaired $fixed of $total damaged LRC files.'
                          : 'No damaged LRC files found.',
                      style: const TextStyle(color: Colors.white70),
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'More',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          ListTile(
            leading: null,
            title: Center(
              child: Text(
                'TimeLyr',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            subtitle: Center(
              child: Text(
                'Find synced lyrics for all your music',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: 30),
          ListTile(
            leading: notificationsEnable == true
                ? Icon(Icons.notifications_on, color: Colors.white)
                : Icon(Icons.notifications_off, color: Colors.white),
            title: Text(
              'Notifications',
              style: TextStyle(color: Colors.white),
            ),
            trailing: Switch(
              value: notificationsEnable,
              activeThumbColor: AppTheme.accent,
              activeTrackColor: AppTheme.accent.withValues(alpha: 0.25),
              inactiveThumbColor: Colors.white70,
              inactiveTrackColor: Colors.white24,
              onChanged: (v) async {
                // Acción al tocar "Notificaciones"
                notificationsEnable = v;
                await NotificationSettings.setEnabled(v);
                setState(() {});
              },
            ),
          ),
          ListTile(
            leading: Icon(Icons.palette, color: Colors.white),
            title: Text('Theme', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              AppTheme.current.name,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
            onTap: _showThemeDialog,
          ),
          ValueListenableBuilder<bool>(
            valueListenable: ViewSettings.folderFilter,
            builder: (context, enabled, _) => SwitchListTile(
              secondary: const Icon(Icons.folder, color: Colors.white),
              title: const Text(
                'Folder filter',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Show a folder button in the Library to filter by folder',
                style: TextStyle(color: Colors.white60, fontSize: 11),
              ),
              value: enabled,
              activeThumbColor: AppTheme.accent,
              onChanged: (value) => ViewSettings.setFolderFilter(value),
            ),
          ),
          ListTile(
            leading: Icon(Icons.sd_card, color: Colors.white),
            title: Text(
              'Storage',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              // Acción al tocar "Configuración"
              showDialog(
                context: context,
                builder: (context) => SelectDirectory(),
              );
            },
          ),
          ListTile(
            leading: Icon(
              watcherEnabled ? Icons.sync : Icons.sync_disabled,
              color: Colors.white,
            ),
            title: Text(
              'Scan on app launch',
              style: TextStyle(color: Colors.white),
            ),
            trailing: Switch(
              value: watcherEnabled,
              activeThumbColor: AppTheme.accent,
              activeTrackColor: AppTheme.accent.withValues(alpha: 0.25),
              inactiveThumbColor: Colors.white70,
              inactiveTrackColor: Colors.white24,
              onChanged: (v) async {
                watcherEnabled = v;
                await AppStorage.saveWatcherEnabled(v);

                setState(() {});
              },
            ),
          ),
          ListTile(
            leading: Icon(Icons.search, color: Colors.white),
            title: Text(
              'Scan music',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              showDialog(context: context, builder: (context) => ScanMusic());
            },
          ),
          ListTile(
            leading: Icon(Icons.healing, color: Colors.orangeAccent),
            title: Text(
              'Repair damaged LRC files',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Re-downloads LRC files with incorrect timestamps',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
            onTap: () => _fixBadLrcs(context),
          ),
          ListTile(
            leading: Icon(Icons.refresh, color: Colors.white),
            title: Text(
              'Retry missing TTML',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Forget failed TTML lookups so they are tried again',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              await TtmlMissCache.clearAll();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Done. Missing TTML will be searched again.'),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.upload_file, color: Colors.white),
            title: Text(
              'Export backup',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Save your lyrics and settings to a file',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
            onTap: _exportBackup,
          ),
          ListTile(
            leading: Icon(Icons.download, color: Colors.white),
            title: Text(
              'Import backup',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Restore lyrics and settings from a backup file',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
            onTap: _importBackup,
          ),
          ListTile(
            leading: Icon(Icons.info, color: Colors.white),
            title: Text('About', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

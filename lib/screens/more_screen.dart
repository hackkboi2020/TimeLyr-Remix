import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timelyr/screens/about_screen.dart';
import 'package:timelyr/services/file_service.dart';
import 'package:timelyr/services/lyrics_service.dart';
import 'package:timelyr/widgets/scan_music.dart';
import 'package:timelyr/widgets/select_directory.dart';
import '../services/notifications_settings.dart';
import '../utils/app_storage.dart';

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
              backgroundColor: const Color(0xFF0D1B2A),
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
                        const LinearProgressIndicator(
                          color: Colors.blueAccent,
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
      backgroundColor: const Color(0xFF0D1B2A),
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
              activeThumbColor: Colors.blueAccent,
              activeTrackColor: Colors.blueAccent.withValues(alpha: 0.25),
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
              activeThumbColor: Colors.blueAccent,
              activeTrackColor: Colors.blueAccent.withValues(alpha: 0.25),
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

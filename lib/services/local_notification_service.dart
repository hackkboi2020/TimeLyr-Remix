import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._internal() {
    _initFuture = _initialize();
  }

  static final LocalNotificationService instance =
      LocalNotificationService._internal();

  /// Keeps `LocalNotificationService()` working while sharing one instance.
  factory LocalNotificationService() => instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  late final Future<void> _initFuture;

  Future<void> _initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
    );
  }

  Future<void> showNotification({
    required int id,
    required int progress,
    required int max,
  }) async {
    await _initFuture;

    final bool done = max > 0 && progress >= max;

    // Progress updates are silent (low importance, shown once, with a progress
    // bar); only the final "complete" notification is allowed to make a sound.
    final AndroidNotificationDetails androidDetails = done
        ? const AndroidNotificationDetails(
            'download_complete',
            'Download complete',
            channelDescription: 'Shown when a lyrics download finishes',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          )
        : AndroidNotificationDetails(
            'download_progress',
            'Lyrics downloads',
            channelDescription: 'Progress of lyrics downloads',
            importance: Importance.low,
            priority: Priority.low,
            onlyAlertOnce: true,
            showProgress: max > 0,
            maxProgress: max,
            progress: progress,
            ongoing: true,
          );

    await _plugin.show(
      id,
      done ? 'Download Complete' : 'Downloading...',
      max > 0 ? 'Progress: $progress / $max' : null,
      NotificationDetails(android: androidDetails),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/notifications_settings.dart';
import 'package:timelyr/theme/app_theme.dart';

class ToggleNotifications extends StatefulWidget {
  const ToggleNotifications({super.key});

  @override
  State<ToggleNotifications> createState() => _ToggleNotificationsState();
}

class _ToggleNotificationsState extends State<ToggleNotifications> {
  bool toggle = true;

  @override
  void initState() {
    super.initState();
    toggleNotifications();
  }

  void toggleNotifications() async {
    toggle = await NotificationSettings.isEnabled();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.background,
      title: toggle != true
          ? Text(
              'Enable notifications',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            )
          : Text(
              'Disable notifications',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
      content: toggle != true
          ? Text(
              'Do you want to enable notifications for song lyrics and updates?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            )
          : Text(
              'Do you want to disable notifications for song lyrics and updates?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
      actions: [
        TextButton(
          onPressed: () async {
            setState(() {
              toggle = !toggle;
            });
            await NotificationSettings.setEnabled(toggle);
            Navigator.of(context).pop(toggle);
          },
          child: Text('Yes', style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('No', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

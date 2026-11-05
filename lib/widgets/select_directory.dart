import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:timelyr/theme/app_theme.dart';

class SelectDirectory extends StatelessWidget {
  const SelectDirectory({super.key});

  static String? selectedPath;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.background,
      title: const Text(
        'Select Music Folder',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white),
      ),
      content: const Text(
        'Please select the folder where your music is stored to continue.',
        textAlign: TextAlign.justify,
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: const Text('Cancel', style: TextStyle(color: Colors.white)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.black87,
          ),
          onPressed: () async {
            //falta integrarlo con el scaneo de archivos
            final newPath = await FilePicker.platform.getDirectoryPath();
            if (newPath != null) {
              SelectDirectory.selectedPath = newPath;
              Navigator.of(context).pop(newPath);
            }
          },
          child: const Text(
            'Select Folder',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

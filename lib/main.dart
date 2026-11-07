import 'package:flutter/material.dart';
import 'package:timelyr/screens/home_screen.dart';
import 'package:timelyr/screens/main_screen.dart';
import 'theme/app_theme.dart';
import 'utils/view_settings.dart';
import 'utils/app_storage.dart';
import 'utils/artwork_cache.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ArtworkCache.init();
  await AppTheme.load();
  await ViewSettings.load();
  final bool firstRun = await AppStorage.isFirstRun();

  runApp(MyApp(firstRun: firstRun));
}

class MyApp extends StatelessWidget {
  final bool firstRun;

  const MyApp({super.key, required this.firstRun});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "TimeLyr",

      home: firstRun ? const HomeScreen() : const MainScreen(),
    );
  }
}

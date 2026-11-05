import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A selectable color preset for the whole app.
class AppThemePreset {
  final String id;
  final String name;
  final Color background;
  final Color backgroundAlt;
  final Color accent;
  final List<Color> gradient;

  const AppThemePreset({
    required this.id,
    required this.name,
    required this.background,
    required this.backgroundAlt,
    required this.accent,
    required this.gradient,
  });
}

class AppTheme {
  static const String _prefKey = 'app_theme_preset';

  /// Available presets. The first one is the original TimeLyr look.
  static const List<AppThemePreset> presets = [
    AppThemePreset(
      id: 'ocean',
      name: 'Ocean',
      background: Color(0xFF0D1B2A),
      backgroundAlt: Color(0xFF1B263B),
      accent: Colors.blueAccent,
      gradient: [Color(0xFF0A2342), Color(0xFF1D3D63), Color(0xFF3A6EA5)],
    ),
    AppThemePreset(
      id: 'midnight',
      name: 'Midnight (AMOLED)',
      background: Color(0xFF000000),
      backgroundAlt: Color(0xFF111111),
      accent: Color(0xFF7C4DFF),
      gradient: [Color(0xFF000000), Color(0xFF0B0B14), Color(0xFF161625)],
    ),
    AppThemePreset(
      id: 'forest',
      name: 'Forest',
      background: Color(0xFF0F1F17),
      backgroundAlt: Color(0xFF1A2E23),
      accent: Color(0xFF2E9E5B),
      gradient: [Color(0xFF0B2A1B), Color(0xFF1E4D36), Color(0xFF3C8D62)],
    ),
    AppThemePreset(
      id: 'sunset',
      name: 'Sunset',
      background: Color(0xFF2A1410),
      backgroundAlt: Color(0xFF3B1F18),
      accent: Color(0xFFE8743B),
      gradient: [Color(0xFF3A1C12), Color(0xFF7A3524), Color(0xFFC4623A)],
    ),
    AppThemePreset(
      id: 'purple',
      name: 'Purple',
      background: Color(0xFF1A1030),
      backgroundAlt: Color(0xFF271A47),
      accent: Color(0xFF8E5CF0),
      gradient: [Color(0xFF1E1040), Color(0xFF3F2680), Color(0xFF6A4BC4)],
    ),
  ];

  static AppThemePreset _current = presets.first;

  static AppThemePreset get current => _current;
  static Color get background => _current.background;
  static Color get backgroundAlt => _current.backgroundAlt;
  static Color get accent => _current.accent;
  static List<Color> get gradient => _current.gradient;

  /// Loads the saved preset. Call once before runApp().
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_prefKey);
      _current = presets.firstWhere(
        (p) => p.id == id,
        orElse: () => presets.first,
      );
    } catch (_) {
      _current = presets.first;
    }
  }

  /// Applies and persists a preset, then rebuilds the whole widget tree.
  static Future<void> setPreset(String id) async {
    _current = presets.firstWhere(
      (p) => p.id == id,
      orElse: () => presets.first,
    );
    _rebuildApp();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, _current.id);
    } catch (_) {}
  }

  static void _rebuildApp() {
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
  }

  static ThemeData mytheme = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      bodyLarge: TextStyle(fontSize: 14),
      bodyMedium: TextStyle(fontSize: 12, color: Colors.white70),
    ),
  );
}

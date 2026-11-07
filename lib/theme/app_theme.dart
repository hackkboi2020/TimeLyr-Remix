import 'dart:convert';

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

  static const String _customKey = 'app_theme_custom';
  static const String _accentKey = 'app_accent_override';

  static AppThemePreset _current = presets.first;
  static AppThemePreset? _custom;
  static Color? _accentOverride;

  static AppThemePreset get current => _current;

  /// The user-made theme, if one was saved.
  static AppThemePreset? get custom => _custom;

  /// Accent set on its own, on top of whichever theme is active.
  static Color? get accentOverride => _accentOverride;

  static Color get background => _current.background;
  static Color get backgroundAlt => _current.backgroundAlt;
  static Color get accent => _accentOverride ?? _current.accent;
  static List<Color> get gradient => _current.gradient;

  static Map<String, dynamic> _presetToJson(AppThemePreset t) => {
    'background': t.background.toARGB32(),
    'backgroundAlt': t.backgroundAlt.toARGB32(),
    'accent': t.accent.toARGB32(),
    'gradient': [for (final c in t.gradient) c.toARGB32()],
  };

  static AppThemePreset? _presetFromJson(dynamic json) {
    if (json is! Map) return null;
    final g = json['gradient'];
    if (g is! List || g.length < 2) return null;
    int? asInt(dynamic v) => v is num ? v.toInt() : null;
    final bg = asInt(json['background']);
    final alt = asInt(json['backgroundAlt']);
    final ac = asInt(json['accent']);
    if (bg == null || alt == null || ac == null) return null;
    return AppThemePreset(
      id: 'custom',
      name: 'Custom',
      background: Color(bg),
      backgroundAlt: Color(alt),
      accent: Color(ac),
      gradient: [for (final c in g) Color(asInt(c) ?? 0xFF000000)],
    );
  }

  /// For backups: the custom theme as JSON, if any.
  static Map<String, dynamic>? customAsJson() =>
      _custom == null ? null : _presetToJson(_custom!);

  /// For backups: restores a custom theme saved by [customAsJson].
  static Future<void> restoreCustom(dynamic json) async {
    final restored = _presetFromJson(json);
    if (restored == null) return;
    await saveCustom(
      background: restored.background,
      backgroundAlt: restored.backgroundAlt,
      accent: restored.accent,
      gradient: restored.gradient,
    );
  }

  /// Loads the saved theme, custom theme and accent. Call before runApp().
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final customRaw = prefs.getString(_customKey);
      if (customRaw != null) {
        _custom = _presetFromJson(jsonDecode(customRaw));
      }
      final accentRaw = prefs.getInt(_accentKey);
      _accentOverride = accentRaw == null ? null : Color(accentRaw);

      final id = prefs.getString(_prefKey);
      _current = id == 'custom' && _custom != null
          ? _custom!
          : presets.firstWhere((p) => p.id == id, orElse: () => presets.first);
    } catch (_) {
      _current = presets.first;
    }
  }

  /// Applies and persists a preset ('custom' selects the user-made theme),
  /// then rebuilds the whole widget tree.
  static Future<void> setPreset(String id) async {
    _current = id == 'custom' && _custom != null
        ? _custom!
        : presets.firstWhere((p) => p.id == id, orElse: () => presets.first);
    _rebuildApp();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, _current.id);
    } catch (_) {}
  }

  /// Saves the user-made theme and switches to it.
  static Future<void> saveCustom({
    required Color background,
    required Color backgroundAlt,
    required Color accent,
    required List<Color> gradient,
  }) async {
    _custom = AppThemePreset(
      id: 'custom',
      name: 'Custom',
      background: background,
      backgroundAlt: backgroundAlt,
      accent: accent,
      gradient: gradient,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_customKey, jsonEncode(_presetToJson(_custom!)));
    } catch (_) {}
    await setPreset('custom');
  }

  /// Sets (or with null clears) the accent color on top of the current theme.
  static Future<void> setAccentOverride(Color? color) async {
    _accentOverride = color;
    _rebuildApp();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (color == null) {
        await prefs.remove(_accentKey);
      } else {
        await prefs.setInt(_accentKey, color.toARGB32());
      }
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_helper.dart';
import 'app_theme.dart';

class AppSettings {
  final ThemeMode themeMode;
  final Color accentColor;
  final Map<String, Color> categoryColors;

  AppSettings({
    required this.themeMode,
    required this.accentColor,
    required this.categoryColors,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    Color? accentColor,
    Map<String, Color>? categoryColors,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      categoryColors: categoryColors ?? this.categoryColors,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(super.initialState) {
    // Populate the static map in AppTheme immediately on initialization
    AppTheme.categoryOverrides = state.categoryColors;
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    String val = 'system';
    if (mode == ThemeMode.dark) val = 'dark';
    if (mode == ThemeMode.light) val = 'light';
    await DBHelper.instance.saveSetting('theme_mode', val);
  }

  Future<void> updateAccentColor(Color color) async {
    state = state.copyWith(accentColor: color);
    await DBHelper.instance.saveSetting('accent_color', color.value.toString());
  }

  Future<void> updateCategoryColor(String category, Color color) async {
    final key = category.toLowerCase().trim();
    final newColors = Map<String, Color>.from(state.categoryColors);
    newColors[key] = color;
    
    state = state.copyWith(categoryColors: newColors);
    AppTheme.categoryOverrides = newColors; // update static map dynamically
    
    await DBHelper.instance.saveSetting('category_color_$key', color.value.toString());
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(AppSettings(
    themeMode: ThemeMode.system,
    accentColor: const Color(0xFF38BDF8),
    categoryColors: {},
  ));
});

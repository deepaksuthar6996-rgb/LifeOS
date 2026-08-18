import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeNotifier extends StateNotifier<Color> {
  ThemeNotifier() : super(const Color(0xFF38BDF8)); // Default: Glacier Blue

  static const Color glacierBlue = Color(0xFF38BDF8);
  static const Color emerald = Color(0xFF10B981);
  static const Color crimson = Color(0xFFF43F5E);
  static const Color ultraviolet = Color(0xFFA855F7);
  static const Color amber = Color(0xFFF59E0B);
  static const Color pureTitanium = Color(0xFFE2E8F0);

  static const List<Color> presets = [
    glacierBlue,
    emerald,
    crimson,
    ultraviolet,
    amber,
    pureTitanium,
  ];

  static const List<String> presetNames = [
    'Glacier Blue',
    'Emerald',
    'Crimson',
    'Ultraviolet',
    'Amber',
    'Pure Titanium',
  ];

  void setAccentColor(Color color) {
    state = color;
  }
}

final themeAccentProvider = StateNotifierProvider<ThemeNotifier, Color>((ref) {
  return ThemeNotifier();
});

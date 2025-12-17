import 'package:flutter/material.dart';

/// Single source of truth for app theme.
/// Access via: ThemeController.themeNotifier.value = ThemeMode.dark/light;
class ThemeController {
  static final ValueNotifier<ThemeMode> themeNotifier =
  ValueNotifier<ThemeMode>(ThemeMode.light);
}

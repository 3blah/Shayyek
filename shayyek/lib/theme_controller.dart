import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  ThemeController();

  static const String _themeKey = 'app_theme_mode';
  static const String _localeKey = 'app_locale_code';

  final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.system);
  final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);

  bool _hasStoredThemeOverride = false;
  bool _hasStoredLocaleOverride = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    _hasStoredThemeOverride = prefs.containsKey(_themeKey);
    _hasStoredLocaleOverride = prefs.containsKey(_localeKey);

    themeMode.value = _parseThemeMode(prefs.getString(_themeKey));
    locale.value = _parseLocaleCode(prefs.getString(_localeKey));
  }

  bool get hasStoredThemeOverride => _hasStoredThemeOverride;

  bool get hasStoredLocaleOverride => _hasStoredLocaleOverride;

  String get themePreference {
    switch (themeMode.value) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  String get localePreference => locale.value?.languageCode ?? 'system';

  String get effectiveLanguageCode =>
      locale.value?.languageCode ?? supportedLanguageCodeForPlatform();

  Future<void> setThemePreference(String value) async {
    final next = _parseThemeMode(value);
    themeMode.value = next;
    _hasStoredThemeOverride = next != ThemeMode.system;

    final prefs = await SharedPreferences.getInstance();
    if (next == ThemeMode.system) {
      await prefs.remove(_themeKey);
    } else {
      await prefs.setString(_themeKey, value.trim().toLowerCase());
    }
  }

  Future<void> setLocalePreference(String value) async {
    final normalized = value.trim().toLowerCase();
    final next = _parseLocaleCode(normalized);
    locale.value = next;
    _hasStoredLocaleOverride = next != null;

    final prefs = await SharedPreferences.getInstance();
    if (next == null) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, normalized);
    }
  }

  void applySessionLocale(String languageCode) {
    if (_hasStoredLocaleOverride) {
      return;
    }
    locale.value = _parseLocaleCode(languageCode);
  }

  void toggle() {
    if (themeMode.value == ThemeMode.dark) {
      themeMode.value = ThemeMode.light;
      _saveThemeOverride('light');
      return;
    }
    themeMode.value = ThemeMode.dark;
    _saveThemeOverride('dark');
  }

  Future<void> _saveThemeOverride(String value) async {
    _hasStoredThemeOverride = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, value);
  }

  ThemeMode _parseThemeMode(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Locale? _parseLocaleCode(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'ar':
        return const Locale('ar');
      case 'en':
        return const Locale('en');
      default:
        return null;
    }
  }

  static String supportedLanguageCodeForPlatform() {
    final systemCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return supportedLanguageCode(systemCode);
  }

  static String supportedLanguageCode(String? value) {
    final code = (value ?? '').trim().toLowerCase();
    if (code.startsWith('ar')) {
      return 'ar';
    }
    return 'en';
  }
}

class ThemeScope extends InheritedWidget {
  const ThemeScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final ThemeController controller;

  static ThemeController? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    return scope?.controller;
  }

  static ThemeController of(BuildContext context) {
    final scope = maybeOf(context);
    return scope!;
  }

  @override
  bool updateShouldNotify(covariant ThemeScope oldWidget) =>
      controller != oldWidget.controller;
}

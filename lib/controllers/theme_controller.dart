import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 라이트/다크 테마 선택 상태. 선택값은 기기에 저장되어 재시작 후에도 유지된다.
class ThemeController extends ChangeNotifier {
  ThemeController({ThemeMode mode = ThemeMode.light, SharedPreferences? prefs})
    : _mode = mode,
      _prefs = prefs;

  static const _key = 'theme_mode';

  /// 저장된 테마를 불러온다. 저장값이 없으면 라이트.
  static Future<ThemeController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_key) == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    return ThemeController(mode: mode, prefs: prefs);
  }

  ThemeMode _mode;
  final SharedPreferences? _prefs;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  void toggle() {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    _prefs?.setString(_key, isDark ? 'dark' : 'light');
  }
}

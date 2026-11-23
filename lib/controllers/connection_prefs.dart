import 'package:shared_preferences/shared_preferences.dart';

/// 마지막으로 연결에 성공한 블루투스 기기 이름 저장소.
///
/// 값이 있으면 다음 실행 때 그 기기로 자동 연결을 시도한다.
/// [SharedPreferences] 없이 만들면 메모리에만 보관한다 (테스트용).
class ConnectionPrefs {
  ConnectionPrefs({String? lastDeviceName, SharedPreferences? prefs})
    : _lastDeviceName = lastDeviceName,
      _prefs = prefs;

  static const _key = 'last_bt_device_name';

  static Future<ConnectionPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ConnectionPrefs(lastDeviceName: prefs.getString(_key), prefs: prefs);
  }

  String? _lastDeviceName;
  final SharedPreferences? _prefs;

  String? get lastDeviceName => _lastDeviceName;

  /// null이면 저장값을 지워 자동 연결을 끈다.
  Future<void> setLastDeviceName(String? name) async {
    _lastDeviceName = name;
    final prefs = _prefs;
    if (prefs == null) return;
    if (name == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, name);
    }
  }
}

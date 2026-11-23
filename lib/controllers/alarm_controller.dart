import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/agv_status.dart';
import '../models/alarm.dart';
import '../services/alarm_output.dart';
import '../services/alarm_policy.dart';
import 'monitor_controller.dart';

/// 알림/진동 켜기·끄기 설정. [SharedPreferences] 없이 만들면 메모리에만 보관.
class AlarmSettings {
  AlarmSettings({
    this.notifyEnabled = true,
    this.vibrateEnabled = true,
    SharedPreferences? prefs,
  }) : _prefs = prefs;

  static const _notifyKey = 'alarm_notify';
  static const _vibrateKey = 'alarm_vibrate';

  /// 저장값이 없으면 둘 다 켜짐.
  static Future<AlarmSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AlarmSettings(
      notifyEnabled: prefs.getBool(_notifyKey) ?? true,
      vibrateEnabled: prefs.getBool(_vibrateKey) ?? true,
      prefs: prefs,
    );
  }

  final SharedPreferences? _prefs;
  bool notifyEnabled;
  bool vibrateEnabled;

  Future<void> save() async {
    await _prefs?.setBool(_notifyKey, notifyEnabled);
    await _prefs?.setBool(_vibrateKey, vibrateEnabled);
  }
}

/// 위험 상태 경보: 상태가 나빠지면 진동 + 화면 상단 배너,
/// 앱이 백그라운드면 안드로이드 시스템 알림.
///
/// 언제 울릴지는 [AlarmPolicy], 실제 출력은 [AlarmOutput]이 담당한다.
/// 데이터 소스와 무관하게 [MonitorController]의 상태만 보므로 더미 모드에서도 동작한다.
class AlarmController extends ChangeNotifier {
  AlarmController({
    required MonitorController monitor,
    required AlarmOutput output,
    AlarmSettings? settings,
    AlarmPolicy? policy,
    this.bannerDuration = const Duration(seconds: 4),
    DateTime Function()? clock,
  }) : _monitor = monitor,
       _output = output,
       _settings = settings ?? AlarmSettings(),
       _policy = policy ?? AlarmPolicy(),
       _clock = clock ?? DateTime.now;

  final MonitorController _monitor;
  final AlarmOutput _output;
  final AlarmSettings _settings;
  final AlarmPolicy _policy;
  final DateTime Function() _clock;

  /// 화면 상단 경보 배너가 보이는 시간.
  final Duration bannerDuration;

  AgvStatus? _lastStatus;
  AlarmEvent? _banner;
  Timer? _bannerTimer;
  AppLifecycleListener? _lifecycle;
  bool _foreground = true;
  bool _hasVibrator = true;
  bool? _notificationPermission;
  bool _started = false;
  bool _disposed = false;

  bool get notifyEnabled => _settings.notifyEnabled;
  bool get vibrateEnabled => _settings.vibrateEnabled;

  /// 기기에 진동 모터가 없으면 false (태블릿 등).
  bool get hasVibrator => _hasVibrator;

  /// 시스템 알림 권한. 아직 요청 전이면 null.
  bool? get notificationPermission => _notificationPermission;

  /// 지금 화면 상단에 보여줄 경보. 없으면 null.
  AlarmEvent? get banner => _banner;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    _foreground = _isForeground(WidgetsBinding.instance.lifecycleState);
    _lifecycle = AppLifecycleListener(
      onStateChange: (s) => _foreground = _isForeground(s),
    );
    _monitor.addListener(_onMonitorChanged);
    // 이미 들어와 있는 상태는 "기준"으로만 삼는다 (시작하자마자 울리지 않게).
    _lastStatus = _monitor.status;
    _policy.update(AlarmStage.of(_monitor.status), _clock());

    _hasVibrator = await _output.init();
    if (notifyEnabled) {
      _notificationPermission = await _output.requestNotificationPermission();
    }
    _notify();
  }

  Future<void> setNotifyEnabled(bool enabled) async {
    _settings.notifyEnabled = enabled;
    if (!enabled) _hideBanner();
    _notify();
    await _settings.save();
    if (enabled && _notificationPermission != true) {
      _notificationPermission = await _output.requestNotificationPermission();
      _notify();
    }
  }

  Future<void> setVibrateEnabled(bool enabled) async {
    _settings.vibrateEnabled = enabled;
    _notify();
    await _settings.save();
  }

  void dismissBanner() => _hideBanner();

  static bool _isForeground(AppLifecycleState? s) => switch (s) {
    AppLifecycleState.paused ||
    AppLifecycleState.hidden ||
    AppLifecycleState.detached => false,
    // resumed, inactive(알림창을 내린 순간 등), null(초기화 전)은 화면에 보이는 상태.
    _ => true,
  };

  void _onMonitorChanged() {
    final status = _monitor.status;
    if (identical(status, _lastStatus)) return; // 연결 상태 변경 등은 무시
    _lastStatus = status;

    final stage = AlarmStage.of(status);
    if (!_policy.update(stage, _clock())) return;
    _fire(AlarmEvent.from(status, stage, _clock()));
  }

  void _fire(AlarmEvent event) {
    // 진동 모터가 없는 기기(태블릿 등)는 진동을 건너뛴다.
    final vibration = _hasVibrator ? event.stage.vibration : null;
    if (_foreground) {
      if (vibrateEnabled && vibration != null) _output.vibrate(vibration);
      if (notifyEnabled) _showBanner(event);
      return;
    }
    // 백그라운드: 시스템 알림(진동 포함). 알림을 못 쓰면 진동만.
    if (notifyEnabled && _notificationPermission == true) {
      _output.showSystemNotification(event, vibrate: vibrateEnabled);
    } else if (vibrateEnabled && vibration != null) {
      _output.vibrate(vibration);
    }
  }

  void _showBanner(AlarmEvent event) {
    _banner = event;
    _bannerTimer?.cancel();
    _bannerTimer = Timer(bannerDuration, _hideBanner);
    _notify();
  }

  void _hideBanner() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
    if (_banner == null) return;
    _banner = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _monitor.removeListener(_onMonitorChanged);
    _lifecycle?.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }
}

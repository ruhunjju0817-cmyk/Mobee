import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/agv_enums.dart';
import '../models/agv_status.dart';
import '../services/agv_data_source.dart';
import '../services/bluetooth_agv_data_source.dart';
import '../services/dummy_agv_data_source.dart';
import 'connection_prefs.dart';

/// 기기 이름으로 블루투스 데이터 소스를 만든다 (테스트에서 가짜 소스 주입용).
typedef BluetoothSourceFactory = AgvDataSource Function(String deviceName);

/// 휴대폰에 페어링된 기기 목록을 불러온다 (테스트에서 가짜 목록 주입용).
typedef PairedDevicesLoader = Future<List<PairedDevice>> Function();

/// 데이터 소스와 UI 사이를 연결하는 상태 관리자.
///
/// 화면은 이 컨트롤러만 구독하므로 데이터 소스를 교체해도 UI 코드는 그대로다.
/// 연결 시트에서 더미 ↔ 블루투스 전환도 이 컨트롤러를 통해 이뤄진다.
class MonitorController extends ChangeNotifier {
  MonitorController(
    AgvDataSource source, {
    ConnectionPrefs? prefs,
    BluetoothSourceFactory? bluetoothSourceFactory,
    PairedDevicesLoader? pairedDevicesLoader,
    this.staleTimeout = const Duration(seconds: 2),
  }) : _source = source,
       _bluetoothDeviceName = source is BluetoothAgvDataSource
           ? source.deviceName
           : null,
       _prefs = prefs ?? ConnectionPrefs(),
       _bluetoothFactory =
           bluetoothSourceFactory ??
           ((name) => BluetoothAgvDataSource(deviceName: name)),
       _pairedDevicesLoader =
           pairedDevicesLoader ?? BluetoothAgvDataSource.loadPairedDevices;

  final ConnectionPrefs _prefs;
  final BluetoothSourceFactory _bluetoothFactory;
  final PairedDevicesLoader _pairedDevicesLoader;

  /// 블루투스 연결 상태에서 이 시간 넘게 패킷이 없으면 [isStale].
  final Duration staleTimeout;

  AgvDataSource _source;

  /// 현재 소스가 블루투스면 그 기기 이름, 더미면 null.
  String? _bluetoothDeviceName;

  AgvStatus _status = AgvStatus.initial();
  ConnectionStatus _connection = ConnectionStatus.disconnected;
  String? _errorMessage;
  bool _disposed = false;

  bool _stale = false;
  Timer? _staleTimer;

  StreamSubscription<AgvStatus>? _statusSub;
  StreamSubscription<ConnectionStatus>? _connectionSub;

  AgvStatus get status => _status;
  ConnectionStatus get connection => _connection;
  String? get errorMessage => _errorMessage;
  String get sourceName => _source.name;

  bool get isBluetooth => _bluetoothDeviceName != null;

  /// 블루투스 연결됨인데 [staleTimeout] 넘게 패킷이 없음 → "데이터 없음" 표시.
  /// 더미 모드에서는 항상 false.
  bool get isStale => _stale;

  /// 현재 연결 대상 블루투스 기기 이름. 더미 모드면 null.
  String? get bluetoothDeviceName => _bluetoothDeviceName;

  /// 마지막으로 연결에 성공한 기기 (다음 실행 시 자동 연결 대상).
  String? get lastDeviceName => _prefs.lastDeviceName;

  /// 더미 모드에서만 버튼으로 상태 전환 가능.
  bool get canSimulate => _source is DummyAgvDataSource;

  /// 상태 전환 버튼을 눌렀을 때 넘어갈 다음 상태.
  DriveState? get nextSimulatedState {
    final source = _source;
    return source is DummyAgvDataSource ? source.nextInCycle() : null;
  }

  /// 현재 소스로 연결 (상단 배지의 "다시 연결", 시트의 "연결" 버튼).
  Future<void> start() => _connect(_source);

  /// 현재 소스 연결 해제. 소스는 그대로 두므로 [start]로 다시 연결할 수 있다.
  Future<void> stop() => _source.disconnect();

  /// 휴대폰에 페어링된 기기 목록. 권한 거부/블루투스 꺼짐 시 예외.
  /// 실패 시 사용자용 문구의 [BluetoothConnectException]만 던진다.
  Future<List<PairedDevice>> loadPairedDevices() async {
    try {
      return await _pairedDevicesLoader();
    } catch (e, st) {
      throw BluetoothConnectException(_userMessage(e, st));
    }
  }

  /// 더미 데이터로 전환. 사용자가 직접 더미를 골랐으므로 자동 연결도 끈다.
  Future<void> useDummy() async {
    await _prefs.setLastDeviceName(null);
    if (!isBluetooth) return;
    _switchTo(DummyAgvDataSource());
    await _connect(_source);
  }

  /// [deviceName] 블루투스 기기로 전환해 연결한다.
  /// 성공하면 다음 실행 때 자동 연결할 기기로 저장한다.
  Future<void> connectBluetooth(String deviceName) async {
    if (_bluetoothDeviceName != deviceName) {
      _switchTo(_bluetoothFactory(deviceName), bluetoothDeviceName: deviceName);
    }
    final source = _source;
    await _connect(source);
    if (identical(source, _source) &&
        source.connectionStatus == ConnectionStatus.connected) {
      await _prefs.setLastDeviceName(deviceName);
    }
  }

  /// 저장된 기기가 있으면 자동 연결을 시도한다.
  ///
  /// 앱은 항상 더미로 시작하므로, 실패하면 더미로 되돌리고 사유를 배너에 띄운다.
  /// (AGV 전원이 꺼져 있었을 수 있으므로 저장값은 지우지 않는다.)
  Future<void> autoConnectLastDevice() async {
    final name = _prefs.lastDeviceName;
    if (name == null || isBluetooth || _disposed) return;

    _switchTo(_bluetoothFactory(name), bluetoothDeviceName: name);
    final source = _source;
    await _connect(source);
    if (_disposed || !identical(source, _source)) return;
    if (source.connectionStatus == ConnectionStatus.connected) return;

    final reason = _errorMessage ?? '연결되지 않았습니다.';
    _switchTo(DummyAgvDataSource());
    await _connect(_source);
    _errorMessage = '마지막 기기 "$name" 자동 연결 실패 — 더미 데이터를 표시합니다.\n$reason';
    _notify();
  }

  /// Normal → Warning → Danger 순환.
  void cycleScenario() {
    final source = _source;
    if (source is DummyAgvDataSource) source.cycleScenario();
  }

  /// 특정 상태(Blocked/Stopped 포함)로 바로 전환.
  void setScenario(DriveState state) {
    final source = _source;
    if (source is DummyAgvDataSource) source.setScenario(state);
  }

  Future<void> _connect(AgvDataSource source) async {
    if (_disposed) return;
    _subscribe();
    _errorMessage = null;
    _notify();
    try {
      await source.connect();
      _syncConnection(source);
    } catch (e, st) {
      _syncConnection(source);
      // 연결 도중 다른 소스로 바뀌었다면 이전 소스의 에러는 무시.
      if (identical(source, _source)) {
        _errorMessage = _userMessage(e, st);
        _notify();
      }
    }
  }

  /// 화면에 보여줄 짧은 문구. 사용자용 예외가 아니면 원본은 디버그 로그로만.
  static String _userMessage(Object e, StackTrace st) {
    if (e is BluetoothConnectException) return e.message;
    logBluetoothError('예상하지 못한 오류', e, st);
    return '연결할 수 없습니다. 기기 상태를 확인하고 다시 시도하세요.';
  }

  /// 스트림 이벤트는 비동기로 도착하므로, connect()가 끝난 시점의 상태를 바로 반영한다.
  void _syncConnection(AgvDataSource source) {
    if (!identical(source, _source) || _connection == source.connectionStatus) {
      return;
    }
    _connection = source.connectionStatus;
    _updateStaleWatch();
    _notify();
  }

  void _subscribe() {
    _statusSub ??= _source.statusStream.listen((status) {
      _status = status;
      _stale = false;
      _armStaleTimer();
      _notify();
    });
    _connectionSub ??= _source.connectionStream.listen((connection) {
      _connection = connection;
      _updateStaleWatch();
      _notify();
    });
  }

  bool get _watchesStale =>
      isBluetooth && _connection == ConnectionStatus.connected;

  /// 연결 상태가 바뀔 때: 블루투스 연결됨이면 감시 시작(이미 감시 중이면 유지),
  /// 그 외에는 감시 중지 및 "데이터 없음" 해제.
  void _updateStaleWatch() {
    if (_watchesStale) {
      if (_staleTimer == null) _armStaleTimer();
    } else {
      _stopStaleWatch();
    }
  }

  void _armStaleTimer() {
    _staleTimer?.cancel();
    _staleTimer = null;
    if (!_watchesStale) return;
    _staleTimer = Timer(staleTimeout, () {
      _staleTimer = null;
      if (!_watchesStale) return;
      _stale = true;
      _notify();
    });
  }

  void _stopStaleWatch() {
    _staleTimer?.cancel();
    _staleTimer = null;
    _stale = false;
  }

  /// 소스를 교체한다. 이전 소스는 정리하고, 화면은 초기 상태로 되돌린다
  /// (이전 소스의 데이터가 새 소스 값처럼 보이지 않도록).
  void _switchTo(AgvDataSource next, {String? bluetoothDeviceName}) {
    if (_disposed) {
      next.dispose();
      return;
    }
    final old = _source;
    _statusSub?.cancel();
    _connectionSub?.cancel();
    _statusSub = null;
    _connectionSub = null;

    _source = next;
    _bluetoothDeviceName = bluetoothDeviceName;
    _status = AgvStatus.initial();
    _connection = next.connectionStatus;
    _errorMessage = null;
    _stopStaleWatch();
    _subscribe();
    _updateStaleWatch();
    _notify();
    old.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _staleTimer?.cancel();
    _statusSub?.cancel();
    _connectionSub?.cancel();
    _source.dispose();
    super.dispose();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/agv_enums.dart';
import '../models/agv_status.dart';
import '../services/agv_data_source.dart';
import '../services/dummy_agv_data_source.dart';

/// 데이터 소스와 UI 사이를 연결하는 상태 관리자.
///
/// 화면은 이 컨트롤러만 구독하므로 데이터 소스를 교체해도 UI 코드는 그대로다.
class MonitorController extends ChangeNotifier {
  MonitorController(this._source);

  final AgvDataSource _source;

  AgvStatus _status = AgvStatus.initial();
  ConnectionStatus _connection = ConnectionStatus.disconnected;
  String? _errorMessage;
  bool _disposed = false;

  StreamSubscription<AgvStatus>? _statusSub;
  StreamSubscription<ConnectionStatus>? _connectionSub;

  AgvStatus get status => _status;
  ConnectionStatus get connection => _connection;
  String? get errorMessage => _errorMessage;
  String get sourceName => _source.name;

  /// 더미 모드에서만 버튼으로 상태 전환 가능.
  bool get canSimulate => _source is DummyAgvDataSource;

  /// 상태 전환 버튼을 눌렀을 때 넘어갈 다음 상태.
  DriveState? get nextSimulatedState {
    final source = _source;
    return source is DummyAgvDataSource ? source.nextInCycle() : null;
  }

  Future<void> start() async {
    _statusSub ??= _source.statusStream.listen((status) {
      _status = status;
      _notify();
    });
    _connectionSub ??= _source.connectionStream.listen((connection) {
      _connection = connection;
      _notify();
    });

    try {
      _errorMessage = null;
      await _source.connect();
    } catch (e) {
      _errorMessage = e.toString();
      _notify();
    }
  }

  Future<void> stop() => _source.disconnect();

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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _statusSub?.cancel();
    _connectionSub?.cancel();
    _source.dispose();
    super.dispose();
  }
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/agv_enums.dart';
import '../models/agv_status.dart';
import '../models/sensor_data.dart';
import 'agv_data_source.dart';

/// Bluetooth 없이 동작하는 더미 데이터 소스.
///
/// 시나리오(주행 상태)별 프리셋 값에 약간의 노이즈를 섞어
/// [tickInterval]마다 실시간 데이터처럼 방출한다.
class DummyAgvDataSource implements AgvDataSource {
  DummyAgvDataSource({
    this.tickInterval = const Duration(seconds: 1),
    Random? random,
  }) : _random = random ?? Random();

  /// 버튼으로 순환하는 시나리오 순서.
  static const cycleOrder = [
    DriveState.normal,
    DriveState.warning,
    DriveState.danger,
  ];

  final Duration tickInterval;
  final Random _random;

  final _statusController = StreamController<AgvStatus>.broadcast();
  final _connectionController = StreamController<ConnectionStatus>.broadcast();

  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  DriveState _scenario = DriveState.normal;
  Timer? _timer;

  /// 타이머 틱 수. Normal 순찰 중 Zone 4 통과 시점 계산용.
  int _tick = 0;

  /// Normal 시나리오에서 [zone4Period] 틱마다 마지막 [zone4Duration] 틱 동안
  /// Zone 4 구간을 지나간다 (예: 12초 중 3초). 시작 직후는 항상 Zone 1.
  static const zone4Period = 12;
  static const zone4Duration = 3;

  @override
  String get name => 'DUMMY';

  @override
  Stream<AgvStatus> get statusStream => _statusController.stream;

  @override
  Stream<ConnectionStatus> get connectionStream => _connectionController.stream;

  @override
  ConnectionStatus get connectionStatus => _connectionStatus;

  DriveState get currentScenario => _scenario;

  @override
  Future<void> connect() async {
    if (_connectionStatus == ConnectionStatus.connected) return;
    _setConnection(ConnectionStatus.connected);
    _emit();
    _timer = Timer.periodic(tickInterval, (_) => advanceTick());
  }

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    _timer = null;
    _setConnection(ConnectionStatus.disconnected);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _statusController.close();
    _connectionController.close();
  }

  /// Normal → Warning → Danger → Normal 순서의 다음 시나리오.
  /// 현재 시나리오가 순환 목록에 없으면(Blocked/Stopped) Normal부터 시작.
  DriveState nextInCycle() {
    final index = cycleOrder.indexOf(_scenario);
    if (index < 0) return cycleOrder.first;
    return cycleOrder[(index + 1) % cycleOrder.length];
  }

  void cycleScenario() => setScenario(nextInCycle());

  void setScenario(DriveState scenario) {
    _scenario = scenario;
    _emit();
  }

  /// 타이머 한 틱 진행 (테스트에서 시간 대기 없이 호출 가능).
  @visibleForTesting
  void advanceTick() {
    _tick++;
    _emit();
  }

  void _setConnection(ConnectionStatus status) {
    _connectionStatus = status;
    if (!_connectionController.isClosed) _connectionController.add(status);
  }

  void _emit() {
    if (_statusController.isClosed) return;
    if (_connectionStatus != ConnectionStatus.connected) return;
    _statusController.add(_buildStatus(_scenario));
  }

  AgvStatus _buildStatus(DriveState scenario) {
    // Unknown 등 프리셋이 없는 상태는 정지 프리셋 값으로.
    final preset = _presets[scenario] ?? _presets[DriveState.stopped]!;
    final s = preset.sensors;
    final moving = scenario != DriveState.stopped;
    return AgvStatus(
      zone: _zoneFor(scenario, preset.zone),
      driveState: scenario,
      hazards: preset.hazards,
      sensors: SensorData(
        frontDistanceCm: _jitterPct(s.frontDistanceCm),
        leftDistanceCm: _jitterPct(s.leftDistanceCm),
        rightDistanceCm: _jitterPct(s.rightDistanceCm),
        tiltDeg: moving ? _jitter(s.tiltDeg, 0.3) : s.tiltDeg,
        vibrationG: moving ? _jitter(s.vibrationG, 0.04) : 0,
      ),
      timestamp: DateTime.now(),
    );
  }

  AgvZone _zoneFor(DriveState scenario, AgvZone presetZone) {
    if (scenario != DriveState.normal) return presetZone;
    final inZone4 = _tick % zone4Period >= zone4Period - zone4Duration;
    return inZone4 ? AgvZone.zone4 : presetZone;
  }

  /// null(미사용 센서)은 그대로 둔다.
  double? _jitter(double? value, double amount) => value == null
      ? null
      : max(0, value + (_random.nextDouble() * 2 - 1) * amount);

  double? _jitterPct(double? value) =>
      value == null ? null : _jitter(value, value * 0.03);

  // 센서 값은 [SensorThresholds] 기준으로 각 시나리오에 맞게 설정.
  static const _presets = <DriveState, _ScenarioPreset>{
    DriveState.normal: _ScenarioPreset(
      zone: AgvZone.zone1,
      hazards: {},
      sensors: SensorData(
        frontDistanceCm: 150,
        leftDistanceCm: 40,
        rightDistanceCm: 42,
        tiltDeg: 1.2,
        vibrationG: 0.12,
      ),
    ),
    DriveState.warning: _ScenarioPreset(
      zone: AgvZone.zone2,
      hazards: {HazardType.sideBlindSpot},
      sensors: SensorData(
        frontDistanceCm: 40, // 20~50: 경고(감속)
        leftDistanceCm: 11, // 8~15: 경고
        rightDistanceCm: 30,
        tiltDeg: 3.5,
        vibrationG: 0.38,
      ),
    ),
    DriveState.danger: _ScenarioPreset(
      zone: AgvZone.zone3,
      hazards: {
        HazardType.frontObstacle,
        HazardType.collision,
        HazardType.tilt,
      },
      sensors: SensorData(
        frontDistanceCm: 15, // 20 미만: 위험(정지)
        leftDistanceCm: 25,
        rightDistanceCm: 20,
        tiltDeg: 12.5,
        vibrationG: 1.35,
      ),
    ),
    DriveState.blocked: _ScenarioPreset(
      zone: AgvZone.zone2,
      hazards: {HazardType.frontObstacle},
      sensors: SensorData(
        frontDistanceCm: 6,
        leftDistanceCm: 6, // 8 미만: 위험
        rightDistanceCm: 7,
        tiltDeg: 0.8,
        vibrationG: 0.05,
      ),
    ),
    DriveState.stopped: _ScenarioPreset(
      zone: AgvZone.unknown,
      hazards: {HazardType.lineLost},
      sensors: SensorData(
        frontDistanceCm: 200,
        leftDistanceCm: 60,
        rightDistanceCm: 55,
        tiltDeg: 0,
        vibrationG: 0,
      ),
    ),
  };
}

class _ScenarioPreset {
  const _ScenarioPreset({
    required this.zone,
    required this.hazards,
    required this.sensors,
  });

  final AgvZone zone;
  final Set<HazardType> hazards;
  final SensorData sensors;
}

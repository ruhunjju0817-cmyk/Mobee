import 'dart:async';
import 'dart:math';

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

  @override
  String get name => 'DUMMY';

  @override
  Stream<AgvStatus> get statusStream => _statusController.stream;

  @override
  Stream<ConnectionStatus> get connectionStream =>
      _connectionController.stream;

  @override
  ConnectionStatus get connectionStatus => _connectionStatus;

  DriveState get currentScenario => _scenario;

  @override
  Future<void> connect() async {
    if (_connectionStatus == ConnectionStatus.connected) return;
    _setConnection(ConnectionStatus.connected);
    _emit();
    _timer = Timer.periodic(tickInterval, (_) => _emit());
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
    final preset = _presets[scenario]!;
    final s = preset.sensors;
    final moving = scenario != DriveState.stopped;
    return AgvStatus(
      zone: preset.zone,
      driveState: scenario,
      hazards: preset.hazards,
      sensors: SensorData(
        frontDistanceCm: _jitter(s.frontDistanceCm, s.frontDistanceCm * 0.03),
        leftDistanceCm: _jitter(s.leftDistanceCm, s.leftDistanceCm * 0.03),
        rightDistanceCm: _jitter(s.rightDistanceCm, s.rightDistanceCm * 0.03),
        tiltDeg: moving ? _jitter(s.tiltDeg, 0.3) : s.tiltDeg,
        vibrationG: moving ? _jitter(s.vibrationG, 0.04) : 0,
      ),
      timestamp: DateTime.now(),
    );
  }

  double _jitter(double value, double amount) =>
      max(0, value + (_random.nextDouble() * 2 - 1) * amount);

  static const _presets = <DriveState, _ScenarioPreset>{
    DriveState.normal: _ScenarioPreset(
      zone: AgvZone.zone1,
      hazards: {},
      sensors: SensorData(
        frontDistanceCm: 150,
        leftDistanceCm: 80,
        rightDistanceCm: 85,
        tiltDeg: 1.2,
        vibrationG: 0.12,
      ),
    ),
    DriveState.warning: _ScenarioPreset(
      zone: AgvZone.zone2,
      hazards: {HazardType.sideBlindSpot},
      sensors: SensorData(
        frontDistanceCm: 95,
        leftDistanceCm: 25,
        rightDistanceCm: 70,
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
        frontDistanceCm: 18,
        leftDistanceCm: 50,
        rightDistanceCm: 35,
        tiltDeg: 12.5,
        vibrationG: 1.35,
      ),
    ),
    DriveState.blocked: _ScenarioPreset(
      zone: AgvZone.zone2,
      hazards: {HazardType.frontObstacle},
      sensors: SensorData(
        frontDistanceCm: 6,
        leftDistanceCm: 30,
        rightDistanceCm: 28,
        tiltDeg: 0.8,
        vibrationG: 0.05,
      ),
    ),
    DriveState.stopped: _ScenarioPreset(
      zone: AgvZone.unknown,
      hazards: {},
      sensors: SensorData(
        frontDistanceCm: 200,
        leftDistanceCm: 100,
        rightDistanceCm: 100,
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

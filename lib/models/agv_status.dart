import 'agv_enums.dart';
import 'sensor_data.dart';

/// 한 시점의 AGV 전체 상태 스냅샷.
///
/// 더미 데이터든 Bluetooth 데이터든 최종적으로 이 객체로 변환되어 UI에 전달된다.
class AgvStatus {
  const AgvStatus({
    required this.zone,
    required this.driveState,
    required this.hazards,
    required this.sensors,
    required this.timestamp,
    this.hasData = true,
  });

  /// 아직 패킷을 한 번도 받지 않은 상태. 센서는 모두 "-"(값 없음)로 표시된다.
  factory AgvStatus.initial() => AgvStatus(
    zone: AgvZone.unknown,
    driveState: DriveState.stopped,
    hazards: const {},
    sensors: SensorData.empty,
    timestamp: DateTime.now(),
    hasData: false,
  );

  final AgvZone zone;
  final DriveState driveState;
  final Set<HazardType> hazards;
  final SensorData sensors;
  final DateTime timestamp;

  /// false면 실제 수신값이 아닌 초기 자리표시 상태 ([AgvStatus.initial]).
  final bool hasData;

  bool hasHazard(HazardType type) => hazards.contains(type);

  /// H의 COLLISION/TILT를 S보다 먼저 보는 최우선 경보 ([AlertPriority] 참고).
  AlertPriority get topAlert {
    if (hasHazard(HazardType.collision)) return AlertPriority.collision;
    if (hasHazard(HazardType.tilt)) return AlertPriority.tilt;
    return switch (driveState) {
      DriveState.blocked => AlertPriority.blocked,
      DriveState.danger => AlertPriority.danger,
      DriveState.warning => AlertPriority.warning,
      DriveState.normal => AlertPriority.normal,
      DriveState.stopped || DriveState.unknown => AlertPriority.none,
    };
  }

  AgvStatus copyWith({
    AgvZone? zone,
    DriveState? driveState,
    Set<HazardType>? hazards,
    SensorData? sensors,
    DateTime? timestamp,
    bool? hasData,
  }) {
    return AgvStatus(
      zone: zone ?? this.zone,
      driveState: driveState ?? this.driveState,
      hazards: hazards ?? this.hazards,
      sensors: sensors ?? this.sensors,
      timestamp: timestamp ?? this.timestamp,
      hasData: hasData ?? this.hasData,
    );
  }
}

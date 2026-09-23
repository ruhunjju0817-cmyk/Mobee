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
  });

  factory AgvStatus.initial() => AgvStatus(
        zone: AgvZone.unknown,
        driveState: DriveState.stopped,
        hazards: const {},
        sensors: SensorData.zero,
        timestamp: DateTime.now(),
      );

  final AgvZone zone;
  final DriveState driveState;
  final Set<HazardType> hazards;
  final SensorData sensors;
  final DateTime timestamp;

  bool hasHazard(HazardType type) => hazards.contains(type);

  AgvStatus copyWith({
    AgvZone? zone,
    DriveState? driveState,
    Set<HazardType>? hazards,
    SensorData? sensors,
    DateTime? timestamp,
  }) {
    return AgvStatus(
      zone: zone ?? this.zone,
      driveState: driveState ?? this.driveState,
      hazards: hazards ?? this.hazards,
      sensors: sensors ?? this.sensors,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

import 'sensor_thresholds.dart';

export 'sensor_thresholds.dart';

/// 센서값의 위험 수준. [unused]는 센서 미사용/값 없음.
enum SensorLevel { safe, caution, critical, unused }

/// AGV 센서 측정값.
///
/// 각 값이 null이면 그 센서는 미사용(패킷에서 -1 또는 필드 없음)이다.
/// 예: 우측 ToF 미장착, IMU 미연결.
class SensorData {
  const SensorData({
    this.frontDistanceCm,
    this.leftDistanceCm,
    this.rightDistanceCm,
    this.tiltDeg,
    this.vibrationG,
  });

  /// 모든 값 없음. 아직 패킷을 받지 않은 초기 상태에 사용.
  static const empty = SensorData();

  /// 정면 초음파 거리 (cm)
  final double? frontDistanceCm;

  /// 좌측 ToF 거리 (cm)
  final double? leftDistanceCm;

  /// 우측 ToF 거리 (cm)
  final double? rightDistanceCm;

  /// IMU 기울기 크기 (deg, 0 이상)
  final double? tiltDeg;

  /// 진동 (g)
  final double? vibrationG;

  SensorLevel get frontLevel => _distanceLevel(
    frontDistanceCm,
    SensorThresholds.frontCautionCm,
    SensorThresholds.frontCriticalCm,
  );

  SensorLevel get leftLevel => _distanceLevel(
    leftDistanceCm,
    SensorThresholds.sideCautionCm,
    SensorThresholds.sideCriticalCm,
  );

  SensorLevel get rightLevel => _distanceLevel(
    rightDistanceCm,
    SensorThresholds.sideCautionCm,
    SensorThresholds.sideCriticalCm,
  );

  SensorLevel get tiltLevel => _magnitudeLevel(
    tiltDeg?.abs(),
    SensorThresholds.tiltCautionDeg,
    SensorThresholds.tiltCriticalDeg,
  );

  SensorLevel get vibrationLevel => _magnitudeLevel(
    vibrationG,
    SensorThresholds.vibrationCautionG,
    SensorThresholds.vibrationCriticalG,
  );

  /// 거리: 가까울수록 위험. 임계값 **미만**이면 해당 단계.
  static SensorLevel _distanceLevel(
    double? value,
    double caution,
    double critical,
  ) {
    if (value == null) return SensorLevel.unused;
    if (value < critical) return SensorLevel.critical;
    if (value < caution) return SensorLevel.caution;
    return SensorLevel.safe;
  }

  /// 기울기/진동: 클수록 위험. 임계값 **이상**이면 해당 단계.
  static SensorLevel _magnitudeLevel(
    double? value,
    double caution,
    double critical,
  ) {
    if (value == null) return SensorLevel.unused;
    if (value >= critical) return SensorLevel.critical;
    if (value >= caution) return SensorLevel.caution;
    return SensorLevel.safe;
  }
}

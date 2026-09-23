/// 센서값의 위험 수준.
enum SensorLevel { safe, caution, critical }

/// 센서별 경고/위험 임계값.
class SensorThresholds {
  const SensorThresholds._();

  static const double frontCautionCm = 80;
  static const double frontCriticalCm = 30;
  static const double sideCautionCm = 40;
  static const double sideCriticalCm = 15;
  static const double tiltCautionDeg = 5;
  static const double tiltCriticalDeg = 10;
  static const double vibrationCautionG = 0.5;
  static const double vibrationCriticalG = 1.0;
}

/// AGV 센서 측정값.
class SensorData {
  const SensorData({
    required this.frontDistanceCm,
    required this.leftDistanceCm,
    required this.rightDistanceCm,
    required this.tiltDeg,
    required this.vibrationG,
  });

  static const zero = SensorData(
    frontDistanceCm: 0,
    leftDistanceCm: 0,
    rightDistanceCm: 0,
    tiltDeg: 0,
    vibrationG: 0,
  );

  /// 전방 초음파/라이다 거리 (cm)
  final double frontDistanceCm;

  /// 좌측 거리 (cm)
  final double leftDistanceCm;

  /// 우측 거리 (cm)
  final double rightDistanceCm;

  /// IMU 기울기 (deg)
  final double tiltDeg;

  /// 진동 (g)
  final double vibrationG;

  SensorLevel get frontLevel => _distanceLevel(frontDistanceCm,
      SensorThresholds.frontCautionCm, SensorThresholds.frontCriticalCm);

  SensorLevel get leftLevel => _distanceLevel(leftDistanceCm,
      SensorThresholds.sideCautionCm, SensorThresholds.sideCriticalCm);

  SensorLevel get rightLevel => _distanceLevel(rightDistanceCm,
      SensorThresholds.sideCautionCm, SensorThresholds.sideCriticalCm);

  SensorLevel get tiltLevel => _magnitudeLevel(tiltDeg.abs(),
      SensorThresholds.tiltCautionDeg, SensorThresholds.tiltCriticalDeg);

  SensorLevel get vibrationLevel => _magnitudeLevel(vibrationG,
      SensorThresholds.vibrationCautionG, SensorThresholds.vibrationCriticalG);

  static SensorLevel _distanceLevel(
      double value, double caution, double critical) {
    if (value <= critical) return SensorLevel.critical;
    if (value <= caution) return SensorLevel.caution;
    return SensorLevel.safe;
  }

  static SensorLevel _magnitudeLevel(
      double value, double caution, double critical) {
    if (value >= critical) return SensorLevel.critical;
    if (value >= caution) return SensorLevel.caution;
    return SensorLevel.safe;
  }

  SensorData copyWith({
    double? frontDistanceCm,
    double? leftDistanceCm,
    double? rightDistanceCm,
    double? tiltDeg,
    double? vibrationG,
  }) {
    return SensorData(
      frontDistanceCm: frontDistanceCm ?? this.frontDistanceCm,
      leftDistanceCm: leftDistanceCm ?? this.leftDistanceCm,
      rightDistanceCm: rightDistanceCm ?? this.rightDistanceCm,
      tiltDeg: tiltDeg ?? this.tiltDeg,
      vibrationG: vibrationG ?? this.vibrationG,
    );
  }
}

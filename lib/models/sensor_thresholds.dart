/// 센서 임계값 모음. **Arduino 펌웨어와 같은 값을 유지해야 한다.**
///
/// 앱은 이 값으로 센서 카드의 색(정상/경고/위험)만 결정한다.
/// 주행 상태(S)와 위험 요소(H)는 MCU가 판단해 보내므로 앱이 다시 계산하지 않는다.
/// 값을 바꾸면 docs/PACKET.md의 임계값 표도 함께 고칠 것.
class SensorThresholds {
  const SensorThresholds._();

  // ── 정면 초음파 (F, cm) ── 50 이상 정상 / 20~50 경고(감속) / 20 미만 위험(정지)

  /// 이 값 **미만**이면 경고.
  static const double frontCautionCm = 50;

  /// 이 값 **미만**이면 위험.
  static const double frontCriticalCm = 20;

  // ── 측면 ToF (L/R, cm) ── 15 이상 정상 / 8~15 경고 / 8 미만 위험

  /// 이 값 **미만**이면 경고.
  static const double sideCautionCm = 15;

  /// 이 값 **미만**이면 위험.
  static const double sideCriticalCm = 8;

  // ── IMU (T, V) ── Arduino 기준 미정. 앱 자체 표시 기준.

  /// 기울기가 이 값 **이상**이면 경고 (deg).
  static const double tiltCautionDeg = 5;

  /// 기울기가 이 값 **이상**이면 위험 (deg).
  static const double tiltCriticalDeg = 10;

  /// 진동이 이 값 **이상**이면 경고 (g).
  static const double vibrationCautionG = 0.5;

  /// 진동이 이 값 **이상**이면 위험 (g).
  static const double vibrationCriticalG = 1.0;
}

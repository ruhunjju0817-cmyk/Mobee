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

  // ── 측면 (cm) ── 15 이상 정상 / 8~15 경고 / 8 미만 위험

  /// 이 값 **미만**이면 경고.
  static const double sideCautionCm = 15;

  /// 이 값 **미만**이면 위험.
  static const double sideCriticalCm = 8;

  // ── 좌측 ToF (L, cm) ── 측면 기준

  static const double leftCautionCm = sideCautionCm;
  static const double leftCriticalCm = sideCriticalCm;

  // ── 우측 초음파 (R, cm) ── 9주차에 ToF 고장으로 초음파로 교체.
  // TODO(하드웨어 팀 확인 필요): 초음파용 기준이 정해지면 여기만 바꾼다.
  //  현재는 ToF 때의 측면 기준(15/8)을 그대로 사용.

  static const double rightCautionCm = sideCautionCm;
  static const double rightCriticalCm = sideCriticalCm;

  // ── IMU 기울기 (T, deg) ──
  // Arduino는 T가 10°를 **넘으면**(> 10) S=STOP;H=TILT를 보낸다.
  // 앱의 5° 경고는 앱 화면 표시용으로만 쓰며 Arduino 동작과는 무관하다.

  /// 기울기가 이 값 **이상**이면 경고(노랑). 앱 화면 표시용.
  static const double tiltCautionDeg = 5;

  /// 기울기가 이 값을 **초과**하면 위험(빨강). Arduino의 TILT 정지 기준과 같다.
  static const double tiltCriticalDeg = 10;

  // ── 진동 (V, g) ── Arduino 기준 미정. 앱 자체 표시 기준.

  /// 진동이 이 값 **이상**이면 경고 (g).
  static const double vibrationCautionG = 0.5;

  /// 진동이 이 값 **이상**이면 위험 (g).
  static const double vibrationCriticalG = 1.0;
}

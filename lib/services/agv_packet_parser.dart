import '../models/agv_enums.dart';
import '../models/agv_status.dart';
import '../models/sensor_data.dart';

/// AGV(MCU)에서 Bluetooth로 전송되는 한 줄 텍스트 패킷을 [AgvStatus]로 변환한다.
///
/// 전체 규칙은 `docs/PACKET.md` 참고. 요약:
/// ```
/// Z=2;S=WARN;H=SIDE,TILT;F=95.0;L=-1;R=25.0;T=3.5;V=0.38
/// ```
/// - 필드는 `;` 구분, `키=값`, 순서 무관, 키/S/H는 대소문자 무시
/// - **S가 없는 줄은 패킷이 아니므로 버린다** (null 반환)
/// - Z: 1~4, 그 외/없음 → Unknown
/// - S: NORMAL / WARN / DANGER / BLOCK / STOP, 그 외 → Unknown
/// - H: FRONT, SIDE, COLLISION, TILT, LINE_LOST (`,` 구분, 비우면 없음),
///   모르는 코드 → Unknown 위험 1건으로 표시
/// - F / L / R / T / V: 숫자. 음수(-1)·숫자 아님·필드 없음 → 미사용(null)
///
/// 이 파일을 바꾸면 docs/PACKET.md도 함께 고칠 것.
class AgvPacketParser {
  const AgvPacketParser._();

  /// 미사용 센서를 나타내는 값. 음수는 모두 미사용으로 본다.
  static const unusedSensorValue = -1;

  /// 패킷이 아니면(S 필드 없음) null 반환. 그 외에는 예외 없이 항상 결과를 돌려준다.
  static AgvStatus? parse(String line) {
    final fields = <String, String>{};
    for (final part in line.trim().split(';')) {
      final eq = part.indexOf('=');
      if (eq <= 0) continue;
      fields[part.substring(0, eq).trim().toUpperCase()] = part
          .substring(eq + 1)
          .trim();
    }

    final rawState = fields['S'];
    if (rawState == null) return null;

    final hazards = <HazardType>{};
    for (final code in (fields['H'] ?? '').split(',')) {
      if (code.trim().isEmpty) continue;
      hazards.add(HazardType.fromCode(code));
    }

    return AgvStatus(
      zone: AgvZone.fromCode(int.tryParse(fields['Z'] ?? '') ?? 0),
      driveState: DriveState.fromCode(rawState),
      hazards: hazards,
      sensors: SensorData(
        frontDistanceCm: _sensor(fields['F']),
        leftDistanceCm: _sensor(fields['L']),
        rightDistanceCm: _sensor(fields['R']),
        tiltDeg: _sensor(fields['T']),
        vibrationG: _sensor(fields['V']),
      ),
      timestamp: DateTime.now(),
    );
  }

  /// 센서 값. 없음/숫자 아님/NaN·무한대/음수 → null(미사용).
  static double? _sensor(String? raw) {
    final v = double.tryParse(raw ?? '');
    if (v == null || !v.isFinite || v < 0) return null;
    return v;
  }
}

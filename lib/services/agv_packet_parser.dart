import '../models/agv_enums.dart';
import '../models/agv_status.dart';
import '../models/sensor_data.dart';

/// AGV(MCU)에서 Bluetooth로 전송되는 한 줄 텍스트 패킷을 [AgvStatus]로 변환한다.
///
/// 패킷 형식 (한 줄, `;` 구분, 순서 무관):
/// ```
/// Z=2;S=WARN;H=SIDE,TILT;F=95.0;L=25.0;R=70.0;T=3.5;V=0.38
/// ```
/// - Z: Zone 코드 (1/2/3, 그 외 Unknown)
/// - S: 주행 상태 (NORMAL / WARN / DANGER / BLOCK / STOP)
/// - H: 위험 요소 목록 (FRONT, SIDE, COLLISION, TILT — `,` 구분, 없으면 비움)
/// - F / L / R: 전방 / 좌 / 우 거리 (cm)
/// - T: IMU 기울기 (deg)
/// - V: 진동 (g)
///
/// MCU 펌웨어의 포맷이 확정되면 이 파일만 수정하면 된다.
class AgvPacketParser {
  const AgvPacketParser._();

  /// 파싱 실패 시 null 반환.
  static AgvStatus? parse(String line) {
    final fields = <String, String>{};
    for (final part in line.trim().split(';')) {
      final eq = part.indexOf('=');
      if (eq <= 0) continue;
      fields[part.substring(0, eq).trim().toUpperCase()] =
          part.substring(eq + 1).trim();
    }

    final state = DriveState.fromCode(fields['S'] ?? '');
    if (state == null) return null;

    final hazards = <HazardType>{};
    final rawHazards = fields['H'] ?? '';
    if (rawHazards.isNotEmpty) {
      for (final code in rawHazards.split(',')) {
        final h = HazardType.fromCode(code);
        if (h != null) hazards.add(h);
      }
    }

    double num(String key) => double.tryParse(fields[key] ?? '') ?? 0;

    return AgvStatus(
      zone: AgvZone.fromCode(int.tryParse(fields['Z'] ?? '') ?? 0),
      driveState: state,
      hazards: hazards,
      sensors: SensorData(
        frontDistanceCm: num('F'),
        leftDistanceCm: num('L'),
        rightDistanceCm: num('R'),
        tiltDeg: num('T'),
        vibrationG: num('V'),
      ),
      timestamp: DateTime.now(),
    );
  }
}

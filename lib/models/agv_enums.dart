/// AGV가 현재 위치한 구역.
enum AgvZone {
  zone1('Zone 1', 1),
  zone2('Zone 2', 2),
  zone3('Zone 3', 3),
  zone4('Zone 4', 4),
  unknown('Unknown', 0);

  const AgvZone(this.label, this.code);

  final String label;

  /// 통신 패킷에서 사용하는 숫자 코드.
  final int code;

  static AgvZone fromCode(int code) =>
      values.firstWhere((z) => z.code == code, orElse: () => AgvZone.unknown);
}

/// AGV 주행 상태.
enum DriveState {
  normal('Normal', '정상 주행', 'NORMAL'),
  warning('Warning', '주의 필요', 'WARN'),
  danger('Danger', '위험 감지', 'DANGER'),
  blocked('Blocked', '경로 차단', 'BLOCK'),
  stopped('Stopped', '정지', 'STOP'),

  /// S 값이 위 코드 중 어느 것도 아닐 때. 패킷 코드로는 보내지 않는다.
  unknown('Unknown', '알 수 없는 상태 코드', '');

  const DriveState(this.label, this.description, this.code);

  final String label;
  final String description;

  /// 통신 패킷에서 사용하는 문자열 코드.
  final String code;

  /// 대소문자·앞뒤 공백 무시. 모르는 코드는 [unknown].
  static DriveState fromCode(String code) {
    final upper = code.trim().toUpperCase();
    for (final s in values) {
      if (s != unknown && s.code == upper) return s;
    }
    return unknown;
  }

  /// [unknown]을 뺀 실제 상태들 (칩/더미 시나리오 버튼용).
  static List<DriveState> get known =>
      values.where((s) => s != unknown).toList(growable: false);
}

/// 위험 요소 종류.
enum HazardType {
  frontObstacle('전방 장애물', 'FRONT'),
  sideBlindSpot('측면 사각지대', 'SIDE'),
  collision('충돌', 'COLLISION'),
  tilt('기울어짐', 'TILT'),
  lineLost('라인 이탈', 'LINE_LOST'),

  /// H 목록에 모르는 코드가 섞여 있을 때. 패킷 코드로는 보내지 않는다.
  unknown('알 수 없는 위험', '');

  const HazardType(this.label, this.code);

  final String label;

  /// 통신 패킷에서 사용하는 문자열 코드.
  final String code;

  /// 대소문자·앞뒤 공백 무시. 모르는 코드는 [unknown].
  static HazardType fromCode(String code) {
    final upper = code.trim().toUpperCase();
    for (final h in values) {
      if (h != unknown && h.code == upper) return h;
    }
    return unknown;
  }
}

/// 화면에 표시할 최우선 경보. 위에 있을수록 우선순위가 높다.
///
/// Collision > Tilt > Blocked > Danger > Warning > Normal.
/// 충돌/기울기는 H(위험 요소)로, 나머지는 S(주행 상태)로 받는다.
/// Stopped/Unknown 상태에 해당 위험 요소도 없으면 [none].
enum AlertPriority {
  collision('충돌'),
  tilt('기울어짐'),
  blocked('경로 차단'),
  danger('위험'),
  warning('주의'),
  normal('정상'),
  none('없음');

  const AlertPriority(this.label);

  final String label;
}

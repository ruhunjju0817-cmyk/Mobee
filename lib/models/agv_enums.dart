/// AGV가 현재 위치한 구역.
enum AgvZone {
  zone1('Zone 1', 1),
  zone2('Zone 2', 2),
  zone3('Zone 3', 3),
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
  stopped('Stopped', '정지', 'STOP');

  const DriveState(this.label, this.description, this.code);

  final String label;
  final String description;

  /// 통신 패킷에서 사용하는 문자열 코드.
  final String code;

  static DriveState? fromCode(String code) {
    final upper = code.trim().toUpperCase();
    for (final s in values) {
      if (s.code == upper) return s;
    }
    return null;
  }
}

/// 위험 요소 종류.
enum HazardType {
  frontObstacle('전방 장애물', 'FRONT'),
  sideBlindSpot('측면 사각지대', 'SIDE'),
  collision('충돌', 'COLLISION'),
  tilt('기울어짐', 'TILT');

  const HazardType(this.label, this.code);

  final String label;

  /// 통신 패킷에서 사용하는 문자열 코드.
  final String code;

  static HazardType? fromCode(String code) {
    final upper = code.trim().toUpperCase();
    for (final h in values) {
      if (h.code == upper) return h;
    }
    return null;
  }
}

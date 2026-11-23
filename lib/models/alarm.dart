import 'agv_enums.dart';
import 'agv_status.dart';

/// 진동 패턴 종류.
enum AlarmVibration {
  /// 짧게 1번 (Warning)
  shortOnce([0, 200]),

  /// 짧게 2번 (Danger, 라인 이탈)
  shortTwice([0, 200, 150, 200]),

  /// 길게 1번 (Blocked, 충돌, 기울기)
  long([0, 1000]);

  const AlarmVibration(this.pattern);

  /// Android 진동 패턴 (ms): [대기, 진동, 대기, 진동, ...]
  final List<int> pattern;
}

/// 경보 단계. **위에 있을수록 나쁜 상태**이며, 이 순서로 "나빠짐"을 판단한다.
///
/// [AlertPriority](Collision > Tilt > Blocked > Danger > Warning > Normal)에
/// 라인 이탈을 Danger와 Warning 사이에 끼운 순서다.
/// (라인 이탈은 보통 S=STOP으로 오며, AGV가 멈춰 사람이 개입해야 하므로 Warning보다 위.)
enum AlarmStage {
  collision('COLLISION', AlarmVibration.long),
  tilt('TILT', AlarmVibration.long),
  blocked('BLOCKED', AlarmVibration.long),
  danger('DANGER', AlarmVibration.shortTwice),
  lineLost('LINE LOST', AlarmVibration.shortTwice),
  warning('WARNING', AlarmVibration.shortOnce),

  /// 경보 대상 아님 (Normal, Stopped, Unknown, 데이터 없음).
  none('', null);

  const AlarmStage(this.title, this.vibration);

  /// 배너/알림 제목 (예: "DANGER").
  final String title;
  final AlarmVibration? vibration;

  /// 클수록 나쁨. [none]은 0.
  int get severity => AlarmStage.values.length - 1 - index;

  bool isWorseThan(AlarmStage other) => severity > other.severity;

  /// 대상: S가 WARN/DANGER/BLOCK이거나 H에 COLLISION/TILT/LINE_LOST.
  static AlarmStage of(AgvStatus status) {
    if (!status.hasData) return none;
    if (status.hasHazard(HazardType.collision)) return collision;
    if (status.hasHazard(HazardType.tilt)) return tilt;
    return switch (status.driveState) {
      DriveState.blocked => blocked,
      DriveState.danger => danger,
      _ when status.hasHazard(HazardType.lineLost) => lineLost,
      DriveState.warning => warning,
      _ => none,
    };
  }
}

/// 실제로 울린 경보 1건.
class AlarmEvent {
  AlarmEvent({required this.stage, required this.reason, required this.time});

  /// [status]로부터 이유 문구를 만든다.
  /// 단계를 정한 위험 요소는 제목과 겹치므로 빼고, 남은 위험 요소를 나열한다.
  /// 남는 게 없으면 주행 상태 설명(예: "정지")을 쓴다.
  factory AlarmEvent.from(AgvStatus status, AlarmStage stage, DateTime time) {
    final defining = switch (stage) {
      AlarmStage.collision => HazardType.collision,
      AlarmStage.tilt => HazardType.tilt,
      AlarmStage.lineLost => HazardType.lineLost,
      _ => null,
    };
    final reasons = [
      for (final h in HazardType.values)
        if (h != defining && status.hasHazard(h)) h.label,
    ];
    return AlarmEvent(
      stage: stage,
      reason: reasons.isEmpty
          ? status.driveState.description
          : reasons.join(', '),
      time: time,
    );
  }

  final AlarmStage stage;
  final String reason;
  final DateTime time;

  /// 예: "DANGER · 전방 장애물"
  String get text => '${stage.title} · $reason';
}

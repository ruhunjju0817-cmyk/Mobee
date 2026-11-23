import 'package:flutter_test/flutter_test.dart';
import 'package:mobee/models/agv_enums.dart';
import 'package:mobee/models/agv_status.dart';
import 'package:mobee/models/sensor_data.dart';
import 'package:mobee/services/agv_packet_parser.dart';

AgvStatus _p(String line) => AgvPacketParser.parse(line)!;

/// docs/PACKET.md의 "상태별 예시 패킷"과 동일하게 유지할 것.
const packetDocExamples = <String, (DriveState, AlertPriority)>{
  'Z=1;S=NORMAL;H=;F=150;L=-1;R=40;T=1.2;V=0.12': (
    DriveState.normal,
    AlertPriority.normal,
  ),
  'Z=2;S=WARN;H=SIDE;F=40;L=-1;R=11;T=3.5;V=0.38': (
    DriveState.warning,
    AlertPriority.warning,
  ),
  'Z=3;S=DANGER;H=FRONT;F=15;L=-1;R=25;T=2.0;V=0.60': (
    DriveState.danger,
    AlertPriority.danger,
  ),
  'Z=2;S=BLOCK;H=FRONT;F=6;L=-1;R=6;T=0.8;V=0.05': (
    DriveState.blocked,
    AlertPriority.blocked,
  ),
  'Z=4;S=STOP;H=;F=200;L=-1;R=60;T=0;V=0': (
    DriveState.stopped,
    AlertPriority.none,
  ),
  'Z=3;S=STOP;H=COLLISION;F=3;L=-1;R=20;T=1.0;V=1.80': (
    DriveState.stopped,
    AlertPriority.collision,
  ),
  'Z=2;S=STOP;H=TILT;F=120;L=-1;R=30;T=14.0;V=0.40': (
    DriveState.stopped,
    AlertPriority.tilt,
  ),
  'Z=0;S=STOP;H=LINE_LOST;F=150;L=-1;R=50;T=-1;V=-1': (
    DriveState.stopped,
    AlertPriority.none,
  ),
};

void main() {
  group('패킷 파서', () {
    test('Z=1~4 인식, 그 외는 Unknown', () {
      for (final z in AgvZone.values.where((z) => z != AgvZone.unknown)) {
        expect(_p('Z=${z.code};S=NORMAL').zone, z);
      }
      expect(_p('Z=4;S=NORMAL').zone, AgvZone.zone4);
      for (final bad in ['Z=0', 'Z=5', 'Z=-1', 'Z=A', 'Z=', 'Z=2.0', '']) {
        expect(_p('$bad;S=NORMAL').zone, AgvZone.unknown, reason: bad);
      }
    });

    test('키, S, H는 대소문자/공백 무시', () {
      final s = _p(' z = 2 ; s = warn ; h = side , Tilt,line_lost ');
      expect(s.zone, AgvZone.zone2);
      expect(s.driveState, DriveState.warning);
      expect(s.hazards, {
        HazardType.sideBlindSpot,
        HazardType.tilt,
        HazardType.lineLost,
      });
    });

    test('모르는 S는 Unknown (패킷은 버리지 않음)', () {
      expect(_p('S=FLYING').driveState, DriveState.unknown);
      expect(_p('S=').driveState, DriveState.unknown);
    });

    test('모르는 H 코드는 Unknown 위험 1건, 빈 항목은 무시', () {
      expect(_p('S=STOP;H=COLLISION,FOO,BAR').hazards, {
        HazardType.collision,
        HazardType.unknown,
      });
      expect(_p('S=NORMAL;H=').hazards, isEmpty);
      expect(_p('S=NORMAL;H=,,').hazards, isEmpty);
      expect(_p('S=NORMAL').hazards, isEmpty);
    });

    test('S 필드가 없으면 패킷이 아님', () {
      for (final line in ['', 'garbage', 'Z=1;F=10', ';;;', '=NORMAL']) {
        expect(AgvPacketParser.parse(line), isNull, reason: line);
      }
    });

    test('센서: -1/음수/숫자 아님/필드 없음 → 미사용(null)', () {
      final s = _p('S=NORMAL;F=0;L=-1;R=12.5;V=abc').sensors;
      expect(s.frontDistanceCm, 0);
      expect(s.rightDistanceCm, 12.5);
      expect(s.leftDistanceCm, isNull);
      expect(s.tiltDeg, isNull); // 필드 없음
      expect(s.vibrationG, isNull); // 숫자 아님
      expect(s.leftLevel, SensorLevel.unused);
      expect(s.tiltLevel, SensorLevel.unused);

      final odd = _p('S=NORMAL;F=-5;T=NaN;V=Infinity').sensors;
      expect(odd.frontDistanceCm, isNull);
      expect(odd.tiltDeg, isNull);
      expect(odd.vibrationG, isNull);
    });

    test('잘못된 입력에도 예외 없음', () {
      for (final line in [
        'S',
        'S==',
        '=;=;=',
        'S=NORMAL;Z=99999999999999999999',
        'S=\u{1F600};H=\u{1F600};F=\u{1F600}',
        'S=NORMAL;H=,COLLISION,,',
      ]) {
        expect(
          () => AgvPacketParser.parse(line),
          returnsNormally,
          reason: line,
        );
      }
    });

    test('PACKET.md 예시 패킷', () {
      packetDocExamples.forEach((line, expected) {
        final s = _p(line);
        expect((s.driveState, s.topAlert), expected, reason: line);
      });
      final lineLost = _p(packetDocExamples.keys.last);
      expect(lineLost.hazards, {HazardType.lineLost});
      expect(lineLost.zone, AgvZone.unknown);
      expect(lineLost.sensors.tiltDeg, isNull);

      // 센서 구성: 정면 초음파 + 우측 ToF. 좌측은 미장착이므로 모든 예시가 L=-1.
      for (final line in packetDocExamples.keys) {
        final sensors = _p(line).sensors;
        expect(sensors.leftDistanceCm, isNull, reason: line);
        expect(sensors.rightDistanceCm, isNotNull, reason: line);
        expect(sensors.frontDistanceCm, isNotNull, reason: line);
      }
      // TILT 예시는 Arduino 정지 기준(10° 초과)을 넘는 값.
      final tilt = _p(
        packetDocExamples.entries
            .firstWhere((e) => e.value.$2 == AlertPriority.tilt)
            .key,
      );
      expect(
        tilt.sensors.tiltDeg,
        greaterThan(SensorThresholds.tiltCriticalDeg),
      );
    });
  });

  test('경보 우선순위: Collision > Tilt > Blocked > Danger > Warning > Normal', () {
    AlertPriority top(DriveState s, Set<HazardType> h) => AgvStatus(
      zone: AgvZone.zone1,
      driveState: s,
      hazards: h,
      sensors: SensorData.empty,
      timestamp: DateTime(2026),
    ).topAlert;

    expect(
      top(DriveState.normal, {HazardType.collision, HazardType.tilt}),
      AlertPriority.collision,
    );
    expect(top(DriveState.blocked, {HazardType.tilt}), AlertPriority.tilt);
    expect(
      top(DriveState.blocked, {HazardType.frontObstacle}),
      AlertPriority.blocked,
    );
    expect(top(DriveState.danger, {}), AlertPriority.danger);
    expect(
      top(DriveState.warning, {HazardType.lineLost}),
      AlertPriority.warning,
    );
    expect(top(DriveState.normal, {}), AlertPriority.normal);
    expect(top(DriveState.stopped, {}), AlertPriority.none);
    expect(top(DriveState.unknown, {}), AlertPriority.none);
  });

  group('임계값 (Arduino와 동일)', () {
    SensorLevel front(double v) => SensorData(frontDistanceCm: v).frontLevel;
    SensorLevel side(double v) => SensorData(rightDistanceCm: v).rightLevel;

    test('정면 초음파: 50 이상 정상 / 20~50 경고 / 20 미만 위험', () {
      expect(front(200), SensorLevel.safe);
      expect(front(50), SensorLevel.safe);
      expect(front(49.9), SensorLevel.caution);
      expect(front(20), SensorLevel.caution);
      expect(front(19.9), SensorLevel.critical);
      expect(front(0), SensorLevel.critical);
    });

    test('우측 ToF: 15 이상 정상 / 8~15 경고 / 8 미만 위험', () {
      expect(side(15), SensorLevel.safe);
      expect(side(14.9), SensorLevel.caution);
      expect(side(8), SensorLevel.caution);
      expect(side(7.9), SensorLevel.critical);
    });

    test('기울기: 5° 이상 경고(앱 표시용) / 10° 초과 위험(Arduino TILT 기준)', () {
      SensorLevel tilt(double v) => SensorData(tiltDeg: v).tiltLevel;
      expect(tilt(0), SensorLevel.safe);
      expect(tilt(4.9), SensorLevel.safe);
      expect(tilt(5), SensorLevel.caution);
      expect(tilt(10), SensorLevel.caution); // Arduino도 10°에서는 아직 정지 안 함
      expect(tilt(10.1), SensorLevel.critical);
    });
  });
}

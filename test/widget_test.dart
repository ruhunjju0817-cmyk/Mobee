import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobee/main.dart';
import 'package:mobee/models/agv_enums.dart';
import 'package:mobee/services/agv_packet_parser.dart';
import 'package:mobee/services/dummy_agv_data_source.dart';

void main() {
  testWidgets('대시보드 표시 및 상태 전환 버튼 동작', (tester) async {
    await tester.pumpWidget(const MobeeApp());
    await tester.pump();

    expect(find.text('ZoneGuard Monitor'), findsOneWidget);
    expect(find.text('NORMAL'), findsOneWidget);
    expect(find.text('ZONE 1'), findsOneWidget);

    // 하단 상태 선택 바에서 각 상태로 바로 전환.
    for (final s in [
      DriveState.warning,
      DriveState.danger,
      DriveState.blocked,
      DriveState.stopped,
      DriveState.normal,
    ]) {
      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('scenario-bar')),
        matching: find.text(s.label),
      ));
      await tester.pump();
      expect(find.text(s.label.toUpperCase()), findsOneWidget);
    }
  });

  test('더미 시나리오는 Normal → Warning → Danger 순환', () {
    final source = DummyAgvDataSource();
    expect(source.nextInCycle(), DriveState.warning);
    source.cycleScenario();
    expect(source.nextInCycle(), DriveState.danger);
    source.cycleScenario();
    expect(source.nextInCycle(), DriveState.normal);
    source.setScenario(DriveState.blocked);
    expect(source.nextInCycle(), DriveState.normal);
    source.dispose();
  });

  test('BT 패킷 파싱', () {
    final s = AgvPacketParser.parse(
        'Z=2;S=WARN;H=SIDE,TILT;F=95.0;L=25.0;R=70.0;T=3.5;V=0.38')!;
    expect(s.zone, AgvZone.zone2);
    expect(s.driveState, DriveState.warning);
    expect(s.hazards, {HazardType.sideBlindSpot, HazardType.tilt});
    expect(s.sensors.leftDistanceCm, 25.0);
    expect(AgvPacketParser.parse('garbage'), isNull);
  });
}

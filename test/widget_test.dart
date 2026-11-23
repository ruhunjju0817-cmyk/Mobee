import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobee/controllers/theme_controller.dart';
import 'package:mobee/main.dart';
import 'package:mobee/models/agv_enums.dart';
import 'package:mobee/services/agv_packet_parser.dart';
import 'package:mobee/services/bluetooth_agv_data_source.dart';
import 'package:mobee/services/dummy_agv_data_source.dart';
import 'package:mobee/theme/app_theme.dart';
import 'package:mobee/widgets/zone_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('대시보드 표시 및 상태 전환 버튼 동작', (tester) async {
    await tester.pumpWidget(const MobeeApp());
    await tester.pump();

    expect(find.text('ZoneGuard Monitor'), findsOneWidget);
    expect(find.text('NORMAL'), findsOneWidget);
    expect(find.text('ZONE'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    // 하단 상태 선택 바에서 각 상태로 바로 전환.
    for (final s in [
      DriveState.warning,
      DriveState.danger,
      DriveState.blocked,
      DriveState.stopped,
      DriveState.normal,
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('scenario-bar')),
          matching: find.text(s.label),
        ),
      );
      await tester.pump();
      expect(find.text(s.label.toUpperCase()), findsOneWidget);
    }
  });

  testWidgets('테마 토글 버튼으로 라이트/다크 전환 및 저장', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final theme = await ThemeController.load();
    await tester.pumpWidget(MobeeApp(themeController: theme));
    await tester.pump();

    ThemeMode appMode() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;
    expect(appMode(), ThemeMode.light);

    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();
    expect(appMode(), ThemeMode.dark);

    // 재시작 시 저장된 값으로 복원.
    expect((await ThemeController.load()).mode, ThemeMode.dark);

    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();
    expect(appMode(), ThemeMode.light);
    expect((await ThemeController.load()).mode, ThemeMode.light);
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
      'Z=2;S=WARN;H=SIDE,TILT;F=95.0;L=25.0;R=70.0;T=3.5;V=0.38',
    )!;
    expect(s.zone, AgvZone.zone2);
    expect(s.driveState, DriveState.warning);
    expect(s.hazards, {HazardType.sideBlindSpot, HazardType.tilt});
    expect(s.sensors.leftDistanceCm, 25.0);
    expect(AgvPacketParser.parse('garbage'), isNull);
  });

  test('Z=4 파싱 및 범위 밖 Zone은 Unknown', () {
    final s = AgvPacketParser.parse(
      'Z=4;S=NORMAL;F=150;L=80;R=85;T=1.2;V=0.1',
    )!;
    expect(s.zone, AgvZone.zone4);
    expect(s.zone.label, 'Zone 4');
    expect(AgvPacketParser.parse('Z=5;S=NORMAL')!.zone, AgvZone.unknown);
    expect(AgvPacketParser.parse('Z=;S=NORMAL')!.zone, AgvZone.unknown);
  });

  test('더미 Normal 순찰 중 Zone 4를 주기적으로 통과', () async {
    final source = DummyAgvDataSource(tickInterval: const Duration(hours: 1));
    final zones = <AgvZone>[];
    final sub = source.statusStream.listen((s) => zones.add(s.zone));
    await source.connect(); // 연결 직후 1회 방출
    // 2주기(24틱) 진행.
    for (var i = 0; i < DummyAgvDataSource.zone4Period * 2; i++) {
      source.advanceTick();
    }
    await Future<void>.delayed(Duration.zero);
    expect(zones.first, AgvZone.zone1);
    expect(
      zones.where((z) => z == AgvZone.zone4).length,
      DummyAgvDataSource.zone4Duration * 2,
    );
    expect(zones.toSet(), {AgvZone.zone1, AgvZone.zone4});

    // Normal이 아닌 시나리오는 프리셋 Zone 그대로.
    source.setScenario(DriveState.danger);
    await Future<void>.delayed(Duration.zero);
    expect(zones.last, AgvZone.zone3);
    await sub.cancel();
    source.dispose();
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('Zone 카드 4칩: ${width.toInt()}dp에서 넘치지 않음', (tester) async {
      tester.view.physicalSize = Size(width, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(20),
              child: ZoneCard(zone: AgvZone.zone4),
            ),
          ),
        ),
      );
      for (final z in ['Z1', 'Z2', 'Z3', 'Z4']) {
        expect(find.text(z), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  test('BT 수신 데이터를 \\n 기준으로 잘라 파싱', () async {
    final source = BluetoothAgvDataSource(deviceName: 'HC-05');
    final received = <DriveState>[];
    final sub = source.statusStream.listen((s) => received.add(s.driveState));

    // 패킷이 조각나서 오거나, 한 조각에 여러 줄 + \r\n이 섞여 와도 된다.
    source.addReceivedText('Z=1;S=NOR');
    source.addReceivedText('MAL;F=150\r\nZ=2;S=WARN\nGARBAGE\nZ=3;');
    await Future<void>.delayed(Duration.zero);
    expect(received, [DriveState.normal, DriveState.warning]);
    source.addReceivedText('S=DANGER\n');
    await Future<void>.delayed(Duration.zero);
    expect(received, [
      DriveState.normal,
      DriveState.warning,
      DriveState.danger,
    ]);

    await sub.cancel();
    source.dispose();
  });
}

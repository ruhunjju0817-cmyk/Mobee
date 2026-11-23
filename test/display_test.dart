import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobee/controllers/connection_prefs.dart';
import 'package:mobee/controllers/monitor_controller.dart';
import 'package:mobee/controllers/theme_controller.dart';
import 'package:mobee/models/agv_enums.dart';
import 'package:mobee/models/agv_status.dart';
import 'package:mobee/models/sensor_data.dart';
import 'package:mobee/screens/monitor_screen.dart';
import 'package:mobee/services/agv_data_source.dart';
import 'package:mobee/services/agv_packet_parser.dart';
import 'package:mobee/services/dummy_agv_data_source.dart';
import 'package:mobee/theme/app_theme.dart';
import 'package:mobee/widgets/drive_state_card.dart';
import 'package:mobee/widgets/hazard_card.dart';
import 'package:mobee/widgets/sensor_card.dart';

import 'fakes.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

AgvStatus _packet(String line) => AgvPacketParser.parse(line)!;

void main() {
  testWidgets('미사용 센서는 "미사용"으로 표시', (tester) async {
    await tester.pumpWidget(
      _wrap(SensorCard(sensors: _packet('S=NORMAL;F=120;L=12;R=-1').sensors)),
    );
    expect(find.text('120.0'), findsOneWidget);
    expect(find.text('12.0'), findsOneWidget);
    // R=-1, T/V 필드 없음 → 3개.
    expect(find.text('미사용'), findsNWidgets(3));
  });

  testWidgets('라인 이탈/모르는 위험 코드 표시', (tester) async {
    await tester.pumpWidget(
      _wrap(HazardCard(status: _packet('S=STOP;H=LINE_LOST,WHAT'))),
    );
    expect(find.text('라인 이탈'), findsOneWidget);
    expect(find.text('감지됨'), findsOneWidget);
    expect(find.byKey(const ValueKey('unknown-hazard')), findsOneWidget);
    expect(find.text('위험 요소 감지'), findsOneWidget);
  });

  testWidgets('최우선 경보 표시: 충돌이 Blocked보다 우선', (tester) async {
    await tester.pumpWidget(
      _wrap(HazardCard(status: _packet('S=BLOCK;H=FRONT,COLLISION'))),
    );
    expect(find.text('최우선 경보: 충돌'), findsOneWidget);
    expect(find.byKey(const ValueKey('unknown-hazard')), findsNothing);
  });

  testWidgets('모르는 S는 UNKNOWN으로 표시', (tester) async {
    await tester.pumpWidget(
      _wrap(DriveStateCard(state: _packet('S=???').driveState)),
    );
    expect(find.text('UNKNOWN'), findsOneWidget);
    // 상태 칩에는 Unknown을 넣지 않는다.
    expect(find.text('Unknown'), findsNothing);
  });

  group('데이터 끊김', () {
    MonitorController btController(List<FakeBluetoothSource> created) =>
        MonitorController(
          DummyAgvDataSource(),
          prefs: ConnectionPrefs(),
          bluetoothSourceFactory: (name) {
            final s = FakeBluetoothSource(name);
            created.add(s);
            return s;
          },
          pairedDevicesLoader: () async => const [],
        );

    testWidgets('BT 연결 중 2초 넘게 패킷 없으면 배너+흐림, 수신 시 복구', (tester) async {
      final created = <FakeBluetoothSource>[];
      final c = btController(created);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MonitorScreen(controller: c, theme: ThemeController()),
        ),
      );
      await c.connectBluetooth('HC-05');
      await tester.pump();
      final bt = created.single;
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('dashboard-content')),
          )
          .opacity;

      bt.emit(_packet('Z=4;S=NORMAL;F=150'));
      await tester.pump(const Duration(milliseconds: 1900));
      expect(c.isStale, isFalse);
      expect(find.byKey(const ValueKey('stale-banner')), findsNothing);
      expect(opacity(), 1);

      await tester.pump(const Duration(milliseconds: 200)); // 2.1초 경과
      expect(c.isStale, isTrue);
      expect(find.byKey(const ValueKey('stale-banner')), findsOneWidget);
      expect(opacity(), lessThan(1));

      bt.emit(_packet('Z=4;S=NORMAL;F=150'));
      await tester.pump();
      expect(c.isStale, isFalse);
      expect(find.byKey(const ValueKey('stale-banner')), findsNothing);
      expect(opacity(), 1);

      // 연결이 끊기면 "데이터 없음"이 아니라 배지의 끊김 상태로만 표시.
      await tester.pump(const Duration(seconds: 3));
      expect(c.isStale, isTrue);
      await c.stop();
      await tester.pump();
      expect(c.connection, ConnectionStatus.disconnected);
      expect(c.isStale, isFalse);
      await tester.pump(const Duration(seconds: 3));
      expect(c.isStale, isFalse);

      c.dispose();
    });

    testWidgets('연결 직후 패킷이 한 번도 안 와도 2초 뒤 데이터 없음', (tester) async {
      final c = btController([]);
      await tester.pumpWidget(const SizedBox());
      await c.connectBluetooth('HC-05');
      await tester.pump(const Duration(milliseconds: 2100));
      expect(c.isStale, isTrue);
      c.dispose();
    });

    testWidgets('더미 모드에는 적용 안 함', (tester) async {
      final c = MonitorController(
        DummyAgvDataSource(tickInterval: const Duration(hours: 1)),
      );
      await tester.pumpWidget(const SizedBox());
      await c.start();
      await tester.pump(const Duration(seconds: 5));
      expect(c.connection, ConnectionStatus.connected);
      expect(c.isStale, isFalse);
      c.dispose();
    });
  });

  test('SensorData 미사용 값은 null', () {
    const s = SensorData(frontDistanceCm: 10);
    expect(s.leftDistanceCm, isNull);
    expect(s.leftLevel, SensorLevel.unused);
    expect(DriveState.known, isNot(contains(DriveState.unknown)));
  });
}

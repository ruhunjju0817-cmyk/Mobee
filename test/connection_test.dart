import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobee/controllers/connection_prefs.dart';
import 'package:mobee/controllers/monitor_controller.dart';
import 'package:mobee/controllers/theme_controller.dart';
import 'package:mobee/screens/monitor_screen.dart';
import 'package:mobee/services/agv_data_source.dart';
import 'package:mobee/services/bluetooth_agv_data_source.dart';
import 'package:mobee/services/dummy_agv_data_source.dart';
import 'package:mobee/theme/app_theme.dart';

import 'fakes.dart';

const _devices = [
  PairedDevice(name: 'HC-05', address: '98:D3:31:00:00:01'),
  PairedDevice(name: 'HC-06', address: '98:D3:31:00:00:02'),
];

MonitorController _controller(
  ConnectionPrefs prefs, {
  Set<String> failing = const {},
  List<FakeBluetoothSource>? created,
}) {
  return MonitorController(
    DummyAgvDataSource(),
    prefs: prefs,
    bluetoothSourceFactory: (name) {
      final s = FakeBluetoothSource(name, fail: failing.contains(name));
      created?.add(s);
      return s;
    },
    pairedDevicesLoader: () async => _devices,
  );
}

Future<void> _pumpScreen(WidgetTester tester, MonitorController c) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MonitorScreen(controller: c, theme: ThemeController()),
    ),
  );
  await tester.pump();
}

void main() {
  test('블루투스 연결 성공 시 기기 저장, 더미 선택 시 저장값 삭제', () async {
    final prefs = ConnectionPrefs();
    final created = <FakeBluetoothSource>[];
    final c = _controller(prefs, created: created);
    await c.start();

    await c.connectBluetooth('HC-05');
    expect(c.isBluetooth, isTrue);
    expect(c.bluetoothDeviceName, 'HC-05');
    expect(c.connection, ConnectionStatus.connected);
    expect(prefs.lastDeviceName, 'HC-05');
    expect(c.canSimulate, isFalse);

    // 다른 기기로 바꾸면 이전 소스는 정리된다.
    await c.connectBluetooth('HC-06');
    expect(created.first.disposed, isTrue);
    expect(prefs.lastDeviceName, 'HC-06');

    await c.useDummy();
    expect(c.isBluetooth, isFalse);
    expect(c.canSimulate, isTrue);
    expect(c.connection, ConnectionStatus.connected);
    expect(prefs.lastDeviceName, isNull);
    expect(created.last.disposed, isTrue);
    c.dispose();
  });

  test('연결 실패 시 저장하지 않고 에러 표시', () async {
    final prefs = ConnectionPrefs();
    final c = _controller(prefs, failing: {'HC-05'});
    await c.start();
    await c.connectBluetooth('HC-05');
    expect(c.connection, ConnectionStatus.error);
    expect(c.errorMessage, '기기를 찾을 수 없습니다.');
    expect(prefs.lastDeviceName, isNull);
    c.dispose();
  });

  test('저장된 기기로 자동 연결', () async {
    final c = _controller(ConnectionPrefs(lastDeviceName: 'HC-06'));
    await c.start();
    await c.autoConnectLastDevice();
    expect(c.bluetoothDeviceName, 'HC-06');
    expect(c.connection, ConnectionStatus.connected);
    c.dispose();
  });

  test('자동 연결 실패 시 더미로 복귀, 저장값 유지', () async {
    final prefs = ConnectionPrefs(lastDeviceName: 'HC-05');
    final c = _controller(prefs, failing: {'HC-05'});
    await c.start();
    await c.autoConnectLastDevice();
    expect(c.isBluetooth, isFalse);
    expect(c.connection, ConnectionStatus.connected);
    expect(c.errorMessage, contains('자동 연결 실패'));
    expect(prefs.lastDeviceName, 'HC-05');
    c.dispose();
  });

  test('저장된 기기가 없으면 더미 그대로', () async {
    final c = _controller(ConnectionPrefs());
    await c.start();
    await c.autoConnectLastDevice();
    expect(c.isBluetooth, isFalse);
    c.dispose();
  });

  testWidgets('연결 시트: 블루투스 선택 → 기기 연결 → 해제 → 더미', (tester) async {
    final prefs = ConnectionPrefs();
    final c = _controller(prefs);
    await c.start();
    await _pumpScreen(tester, c);
    expect(find.text('DUMMY'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('connection-button')));
    await tester.pumpAndSettle();
    expect(find.text('데이터 연결'), findsOneWidget);
    expect(find.text('현재: 더미 데이터 · 연결됨'), findsOneWidget);

    // 블루투스 탭: 기기 목록 표시, 기기를 고르기 전에는 연결 버튼 비활성.
    await tester.tap(find.text('블루투스'));
    await tester.pumpAndSettle();
    expect(find.text('HC-05'), findsOneWidget);
    expect(find.text('HC-06'), findsOneWidget);
    expect(find.text('위 목록에서 기기를 선택하세요'), findsOneWidget);

    await tester.tap(find.text('HC-05'));
    await tester.pumpAndSettle();
    expect(find.text('현재: HC-05 · 연결됨'), findsOneWidget);
    expect(find.text('BLUETOOTH'), findsOneWidget);
    expect(prefs.lastDeviceName, 'HC-05');
    // 블루투스 모드에서는 더미용 하단 상태 바가 사라진다.
    expect(find.byKey(const ValueKey('scenario-bar')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('disconnect-button')));
    await tester.pumpAndSettle();
    expect(find.text('현재: HC-05 · 끊김'), findsOneWidget);
    expect(find.text('HC-05에 연결'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('connect-button')));
    await tester.pumpAndSettle();
    expect(find.text('현재: HC-05 · 연결됨'), findsOneWidget);

    await tester.tap(find.text('더미'));
    await tester.pumpAndSettle();
    expect(find.text('현재: 더미 데이터 · 연결됨'), findsOneWidget);
    expect(find.text('DUMMY'), findsOneWidget);
    expect(prefs.lastDeviceName, isNull);
    c.dispose();
  });

  testWidgets('좁은 화면(360dp)에서 앱바 overflow 없음', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final c = _controller(ConnectionPrefs(), failing: {'HC-05'});
    await c.start();
    await c.connectBluetooth('HC-05'); // 가장 긴 "BLUETOOTH 연결 실패" 배지
    await _pumpScreen(tester, c);
    expect(find.text('연결 실패'), findsOneWidget);
    expect(tester.takeException(), isNull);
    c.dispose();
  });
}

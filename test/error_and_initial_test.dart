import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobee/controllers/connection_prefs.dart';
import 'package:mobee/controllers/monitor_controller.dart';
import 'package:mobee/controllers/theme_controller.dart';
import 'package:mobee/models/agv_status.dart';
import 'package:mobee/models/sensor_data.dart';
import 'package:mobee/screens/monitor_screen.dart';
import 'package:mobee/services/agv_data_source.dart';
import 'package:mobee/services/agv_packet_parser.dart';
import 'package:mobee/services/bluetooth_agv_data_source.dart';
import 'package:mobee/services/dummy_agv_data_source.dart';
import 'package:mobee/theme/app_theme.dart';
import 'package:mobee/widgets/sensor_card.dart';

import 'fakes.dart';

const _btChannel = MethodChannel('flutter_bluetooth_serial_plus/methods');
const _permissionChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);

/// 실제 플러그인이 연결 실패 시 던지는 것과 같은 형태의 예외.
final _platformError = PlatformException(
  code: 'connect_error',
  message: 'read failed, socket might closed or timeout, read ret: -1',
  details:
      'java.io.IOException: read failed\n'
      '\tat android.bluetooth.BluetoothSocket.readAll(BluetoothSocket.java:1)',
);

const _expectedConnectMessage = 'HC-06에 연결할 수 없습니다. 모듈 전원과 페어링을 확인하세요.';

/// 권한 허용, 블루투스 켜짐, HC-06 페어링됨 상태에서 [onConnect] / [onBonded]로 동작 지정.
void _mockPlatform({
  Object? Function()? onConnect,
  Object? Function()? onBonded,
}) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_permissionChannel, (call) async {
    // Permission.bluetoothConnect(30) → granted(1)
    if (call.method == 'requestPermissions') return {30: 1};
    if (call.method == 'checkPermissionStatus') return 1;
    return null;
  });
  messenger.setMockMethodCallHandler(_btChannel, (call) async {
    switch (call.method) {
      case 'isEnabled':
        return true;
      case 'getBondedDevices':
        if (onBonded != null) return onBonded();
        return [
          {'name': 'HC-06', 'address': '98:D3:31:00:00:02'},
        ];
      case 'connect':
        if (onConnect != null) return onConnect();
        throw _platformError;
    }
    return null;
  });
}

void _clearMocks() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_permissionChannel, null);
  messenger.setMockMethodCallHandler(_btChannel, null);
}

/// debugPrint 출력을 가로챈다. testWidgets에서는 끝나기 전에 [restore]를 직접 호출할 것
/// (위젯 테스트는 tearDown 전에 debugPrint 복원 여부를 검사한다).
({List<String> logs, void Function() restore}) _captureDebugLog() {
  final logs = <String>[];
  final original = debugPrint;
  debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
  void restore() => debugPrint = original;
  addTearDown(restore);
  return (logs: logs, restore: restore);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(_clearMocks);

  group('연결 실패 문구', () {
    test('PlatformException은 짧은 문구로, 원본은 디버그 로그로만', () async {
      _mockPlatform();
      final logs = _captureDebugLog().logs;
      final source = BluetoothAgvDataSource(deviceName: 'HC-06');

      await expectLater(
        source.connect(),
        throwsA(
          isA<BluetoothConnectException>().having(
            (e) => e.toString(),
            'message',
            _expectedConnectMessage,
          ),
        ),
      );
      expect(source.connectionStatus, ConnectionStatus.error);

      final log = logs.join('\n');
      expect(log, contains('PlatformException'));
      expect(log, contains('read failed'));
      source.dispose();
    });

    test('컨트롤러 에러 메시지에 예외 원문이 없음', () async {
      _mockPlatform();
      _captureDebugLog();
      final c = MonitorController(
        DummyAgvDataSource(),
        prefs: ConnectionPrefs(),
      );
      await c.connectBluetooth('HC-06');
      expect(c.connection, ConnectionStatus.error);
      expect(c.errorMessage, _expectedConnectMessage);
      for (final raw in ['Exception', 'java.', 'socket', 'connect_error']) {
        expect(c.errorMessage, isNot(contains(raw)));
      }
      c.dispose();
    });

    test('페어링 목록 조회 실패도 짧은 문구', () async {
      _mockPlatform(onBonded: () => throw _platformError);
      final logs = _captureDebugLog().logs;
      await expectLater(
        BluetoothAgvDataSource.loadPairedDevices(),
        throwsA(
          isA<BluetoothConnectException>().having(
            (e) => e.message,
            'message',
            '페어링된 기기 목록을 불러올 수 없습니다. 블루투스가 켜져 있는지 확인하세요.',
          ),
        ),
      );
      expect(logs.join('\n'), contains('PlatformException'));
    });

    test('기존 사용자용 문구(페어링 안 됨)는 그대로', () async {
      _mockPlatform();
      final source = BluetoothAgvDataSource(deviceName: 'HC-05');
      await expectLater(
        source.connect(),
        throwsA(
          isA<BluetoothConnectException>().having(
            (e) => e.message,
            'message',
            contains('페어링된 기기 중 "HC-05"'),
          ),
        ),
      );
      source.dispose();
    });

    test('사용자용 예외가 아닌 에러도 원문 대신 기본 문구', () async {
      final logs = _captureDebugLog().logs;
      final c = MonitorController(
        _ThrowingSource(StateError('Bad state: socket closed')),
        prefs: ConnectionPrefs(),
        pairedDevicesLoader: () => throw _platformError,
      );
      await c.start();
      expect(c.errorMessage, '연결할 수 없습니다. 기기 상태를 확인하고 다시 시도하세요.');
      expect(logs.join('\n'), contains('socket closed'));

      await expectLater(
        c.loadPairedDevices(),
        throwsA(
          isA<BluetoothConnectException>().having(
            (e) => e.message,
            'message',
            isNot(contains('PlatformException')),
          ),
        ),
      );
      c.dispose();
    });

    testWidgets('화면 배너에 스택트레이스가 나오지 않음', (tester) async {
      _mockPlatform();
      final capture = _captureDebugLog();
      final c = MonitorController(
        DummyAgvDataSource(),
        prefs: ConnectionPrefs(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MonitorScreen(controller: c, theme: ThemeController()),
        ),
      );
      await c.connectBluetooth('HC-06');
      await tester.pump();

      expect(find.text(_expectedConnectMessage), findsOneWidget);
      expect(find.textContaining('PlatformException'), findsNothing);
      expect(find.textContaining('java.'), findsNothing);
      c.dispose();
      capture.restore();
    });
  });

  group('패킷 수신 전 초기 상태', () {
    test('AgvStatus.initial은 데이터 없음, 센서 전부 null', () {
      final s = AgvStatus.initial();
      expect(s.hasData, isFalse);
      final v = s.sensors;
      expect([
        v.frontDistanceCm,
        v.leftDistanceCm,
        v.rightDistanceCm,
        v.tiltDeg,
        v.vibrationG,
      ], everyElement(isNull));
      expect(v.frontLevel, SensorLevel.unused);
      // 파싱된 패킷은 데이터 있음.
      expect(AgvPacketParser.parse('S=NORMAL')!.hasData, isTrue);
    });

    testWidgets('센서 카드: 데이터 없음이면 모두 "-" 회색', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SensorCard(
                sensors: AgvStatus.initial().sensors,
                hasData: false,
              ),
            ),
          ),
        ),
      );
      final dashes = find.text('-');
      expect(dashes, findsNWidgets(5));
      expect(find.text('0.0'), findsNothing);
      expect(find.text('미사용'), findsNothing);

      final muted = AppTheme.light.extension<AppPalette>()!.textMuted;
      for (final e in dashes.evaluate()) {
        expect((e.widget as Text).style!.color, muted);
      }
    });

    testWidgets('BT 연결 후 첫 패킷 전에는 "-", 수신하면 값 표시', (tester) async {
      final created = <FakeBluetoothSource>[];
      final c = MonitorController(
        DummyAgvDataSource(),
        prefs: ConnectionPrefs(),
        bluetoothSourceFactory: (name) {
          final s = FakeBluetoothSource(name);
          created.add(s);
          return s;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MonitorScreen(controller: c, theme: ThemeController()),
        ),
      );
      await c.connectBluetooth('HC-05');
      await tester.pump();

      expect(c.connection, ConnectionStatus.connected);
      expect(find.text('-'), findsNWidgets(5));
      expect(find.text('0.0'), findsNothing);
      expect(find.text('LAST UPDATE   --:--:--'), findsOneWidget);

      // 2초 넘게 첫 패킷이 없으면 배너에 "마지막 수신 값" 대신 안내 문구.
      await tester.pump(const Duration(milliseconds: 2100));
      expect(find.textContaining('아직 수신된 패킷이 없습니다'), findsOneWidget);

      created.single.emit(
        AgvPacketParser.parse('S=NORMAL;F=150;L=12;R=40;T=-1;V=0.1')!,
      );
      await tester.pump();
      expect(find.text('-'), findsNothing);
      expect(find.text('150.0'), findsOneWidget);
      expect(find.text('미사용'), findsOneWidget); // T=-1
      expect(find.text('LAST UPDATE   --:--:--'), findsNothing);
      c.dispose();
    });
  });
}

class _ThrowingSource extends DummyAgvDataSource {
  _ThrowingSource(this.error);

  final Object error;

  @override
  Future<void> connect() async => throw error;
}

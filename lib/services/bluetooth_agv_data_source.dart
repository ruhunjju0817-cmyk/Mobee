import 'dart:async';

import '../models/agv_status.dart';
import 'agv_data_source.dart';
import 'agv_packet_parser.dart';

/// Bluetooth 데이터 소스 (구현 예정 골격).
///
/// 구현 방법:
/// 1. pubspec.yaml에 BT 패키지 추가
///    - BLE(HM-10 등): `flutter_blue_plus`
///    - Classic SPP(HC-05/06 등): `flutter_bluetooth_serial` 계열
/// 2. Android/iOS 권한 설정 (BLUETOOTH_SCAN, BLUETOOTH_CONNECT, 위치 등)
/// 3. [connect]에서 장치 검색/연결 후 수신 바이트를 줄 단위로 모아
///    [handleIncomingLine]에 전달
/// 4. main.dart에서 `DummyAgvDataSource()` 대신 이 클래스를 주입
class BluetoothAgvDataSource implements AgvDataSource {
  BluetoothAgvDataSource({required this.deviceName});

  /// 연결할 AGV 모듈 이름 (예: "MOBEE-AGV")
  final String deviceName;

  final _statusController = StreamController<AgvStatus>.broadcast();
  final _connectionController = StreamController<ConnectionStatus>.broadcast();
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;

  @override
  String get name => 'BLUETOOTH';

  @override
  Stream<AgvStatus> get statusStream => _statusController.stream;

  @override
  Stream<ConnectionStatus> get connectionStream =>
      _connectionController.stream;

  @override
  ConnectionStatus get connectionStatus => _connectionStatus;

  @override
  Future<void> connect() async {
    _setConnection(ConnectionStatus.connecting);
    // TODO: 장치 검색 → 연결 → 수신 스트림 구독
    //   device.onData.transform(utf8.decoder).transform(const LineSplitter())
    //       .listen(handleIncomingLine);
    //   연결 성공 시 _setConnection(ConnectionStatus.connected);
    _setConnection(ConnectionStatus.error);
    throw UnimplementedError('Bluetooth 연결은 아직 구현되지 않았습니다.');
  }

  @override
  Future<void> disconnect() async {
    // TODO: 수신 구독 취소 및 장치 연결 해제
    _setConnection(ConnectionStatus.disconnected);
  }

  @override
  void dispose() {
    _statusController.close();
    _connectionController.close();
  }

  /// 수신된 한 줄 패킷을 파싱해 스트림으로 내보낸다.
  void handleIncomingLine(String line) {
    final status = AgvPacketParser.parse(line);
    if (status != null && !_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void _setConnection(ConnectionStatus status) {
    _connectionStatus = status;
    if (!_connectionController.isClosed) _connectionController.add(status);
  }
}

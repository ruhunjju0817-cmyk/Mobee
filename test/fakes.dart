import 'dart:async';

import 'package:mobee/models/agv_status.dart';
import 'package:mobee/services/agv_data_source.dart';
import 'package:mobee/services/bluetooth_agv_data_source.dart';

/// 플러그인 없이 동작하는 가짜 블루투스 소스.
class FakeBluetoothSource implements AgvDataSource {
  FakeBluetoothSource(this.deviceName, {this.fail = false});

  final String deviceName;
  final bool fail;
  bool disposed = false;

  final _status = StreamController<AgvStatus>.broadcast();
  final _conn = StreamController<ConnectionStatus>.broadcast();
  ConnectionStatus _state = ConnectionStatus.disconnected;

  @override
  String get name => 'BLUETOOTH';
  @override
  Stream<AgvStatus> get statusStream => _status.stream;
  @override
  Stream<ConnectionStatus> get connectionStream => _conn.stream;
  @override
  ConnectionStatus get connectionStatus => _state;

  void _set(ConnectionStatus s) {
    _state = s;
    if (!_conn.isClosed) _conn.add(s);
  }

  @override
  Future<void> connect() async {
    _set(ConnectionStatus.connecting);
    // 타이머 대신 마이크로태스크로 양보 (testWidgets의 가짜 시계에서도 진행됨).
    await Future<void>.value();
    if (fail) {
      _set(ConnectionStatus.error);
      throw const BluetoothConnectException('기기를 찾을 수 없습니다.');
    }
    _set(ConnectionStatus.connected);
  }

  /// 패킷 1건 수신을 흉내 낸다.
  void emit(AgvStatus status) {
    if (!_status.isClosed) _status.add(status);
  }

  @override
  Future<void> disconnect() async => _set(ConnectionStatus.disconnected);

  @override
  void dispose() {
    disposed = true;
    _status.close();
    _conn.close();
  }
}

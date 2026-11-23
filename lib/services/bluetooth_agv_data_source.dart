import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/agv_status.dart';
import 'agv_data_source.dart';
import 'agv_packet_parser.dart';

/// 클래식 블루투스(SPP) 데이터 소스. HC-05/HC-06 모듈용, Android 전용.
///
/// 1. (Android 12+) BLUETOOTH_CONNECT 런타임 권한 요청
/// 2. 블루투스가 꺼져 있으면 켜기 요청
/// 3. **페어링된 기기 목록**에서 [deviceName]과 이름이 같은 기기를 찾아 연결
///    (검색/페어링은 하지 않는다 — 휴대폰 설정에서 미리 페어링해 둘 것.
///    HC-05/06 기본 PIN은 보통 1234 또는 0000)
/// 4. 수신 바이트를 `\n` 기준으로 잘라 [AgvPacketParser]에 전달
class BluetoothAgvDataSource implements AgvDataSource {
  BluetoothAgvDataSource({required this.deviceName});

  /// 연결할 AGV 모듈의 블루투스 이름 (예: "HC-05", "MOBEE-AGV")
  final String deviceName;

  /// 줄바꿈 없이 이만큼 쌓이면 잘못된 데이터로 보고 버퍼를 비운다.
  static const _maxBufferLength = 1024;

  final _statusController = StreamController<AgvStatus>.broadcast();
  final _connectionController = StreamController<ConnectionStatus>.broadcast();
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;

  BluetoothConnection? _connection;
  StreamSubscription<String>? _inputSub;
  final _lineBuffer = StringBuffer();
  bool _disposed = false;

  /// 휴대폰에 페어링된 기기 목록. 권한 요청과 블루투스 켜기 요청을 먼저 수행한다.
  ///
  /// 기기 검색(discovery)은 하지 않으므로 휴대폰 설정에서 미리 페어링해야 한다.
  /// 이름이 없는 기기는 [deviceName]으로 연결할 수 없어 제외한다.
  ///
  /// 실패 시 항상 사용자용 문구를 담은 [BluetoothConnectException]을 던진다.
  static Future<List<PairedDevice>> loadPairedDevices() async {
    try {
      await _ensurePermission();
      await _ensureBluetoothOn();
      final bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
      return [
        for (final d in bonded)
          if (d.name case final name? when name.isNotEmpty)
            PairedDevice(name: name, address: d.address),
      ];
    } on BluetoothConnectException {
      rethrow;
    } catch (e, st) {
      logBluetoothError('페어링 기기 목록 조회 실패', e, st);
      throw const BluetoothConnectException(
        '페어링된 기기 목록을 불러올 수 없습니다. 블루투스가 켜져 있는지 확인하세요.',
      );
    }
  }

  @override
  String get name => 'BLUETOOTH';

  @override
  Stream<AgvStatus> get statusStream => _statusController.stream;

  @override
  Stream<ConnectionStatus> get connectionStream => _connectionController.stream;

  @override
  ConnectionStatus get connectionStatus => _connectionStatus;

  @override
  Future<void> connect() async {
    if (_connectionStatus == ConnectionStatus.connecting ||
        _connectionStatus == ConnectionStatus.connected) {
      return;
    }
    _setConnection(ConnectionStatus.connecting);

    try {
      final device = await _findPairedDevice();

      final connection = await BluetoothConnection.toAddress(device.address);
      if (_disposed) {
        await connection.close();
        return;
      }
      _connection = connection;
      _lineBuffer.clear();
      // utf8.decoder를 스트림에 걸면 청크 경계에서 잘린 멀티바이트 문자도
      // 다음 청크와 이어서 올바르게 디코딩된다.
      _inputSub = connection.input
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(
            addReceivedText,
            onError: (_) => _handleRemoteClosed(),
            onDone: _handleRemoteClosed,
            cancelOnError: true,
          );
      _setConnection(ConnectionStatus.connected);
    } on BluetoothConnectException {
      _setConnection(ConnectionStatus.error);
      rethrow;
    } catch (e, st) {
      // PlatformException 등 원본은 디버그 로그로만 남기고 화면에는 짧은 문구만.
      logBluetoothError('"$deviceName" 연결 실패', e, st);
      _setConnection(ConnectionStatus.error);
      throw BluetoothConnectException(
        '$deviceName에 연결할 수 없습니다. 모듈 전원과 페어링을 확인하세요.',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    await _closeConnection();
    _setConnection(ConnectionStatus.disconnected);
  }

  @override
  void dispose() {
    _disposed = true;
    _closeConnection();
    _statusController.close();
    _connectionController.close();
  }

  /// 수신된 텍스트 조각을 버퍼에 쌓고 `\n`이 나올 때마다 한 줄씩 파서로 넘긴다.
  ///
  /// 한 패킷이 여러 조각으로 나뉘어 오거나, 한 조각에 여러 패킷이 들어와도 된다.
  @visibleForTesting
  void addReceivedText(String text) {
    var start = 0;
    var newline = text.indexOf('\n');
    while (newline >= 0) {
      _lineBuffer.write(text.substring(start, newline));
      final line = _lineBuffer.toString();
      _lineBuffer.clear();
      // HC-05 예제 코드(Serial.println)는 "\r\n"을 보내므로 '\r'도 제거.
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) handleIncomingLine(trimmed);
      start = newline + 1;
      newline = text.indexOf('\n', start);
    }
    _lineBuffer.write(text.substring(start));
    if (_lineBuffer.length > _maxBufferLength) _lineBuffer.clear();
  }

  /// 수신된 한 줄 패킷을 파싱해 스트림으로 내보낸다.
  void handleIncomingLine(String line) {
    final status = AgvPacketParser.parse(line);
    if (status != null && !_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  static Future<void> _ensurePermission() async {
    // Android 11 이하에서는 BLUETOOTH(설치 시 권한)만으로 충분하며,
    // permission_handler가 bluetoothConnect를 곧바로 granted로 돌려준다.
    final status = await Permission.bluetoothConnect.request();
    if (status.isGranted) return;
    if (status.isPermanentlyDenied) {
      throw const BluetoothConnectException(
        '블루투스 권한이 거부되었습니다. 설정 > 앱 > MOBEE > 권한에서 '
        '"근처 기기"를 허용해 주세요.',
      );
    }
    throw const BluetoothConnectException('블루투스(근처 기기) 권한이 필요합니다.');
  }

  static Future<void> _ensureBluetoothOn() async {
    final bt = FlutterBluetoothSerial.instance;
    if (await bt.isEnabled ?? false) return;
    final enabled = await bt.requestEnable() ?? false;
    if (!enabled) {
      throw const BluetoothConnectException('블루투스가 꺼져 있습니다.');
    }
  }

  Future<PairedDevice> _findPairedDevice() async {
    for (final d in await loadPairedDevices()) {
      if (d.name == deviceName) return d;
    }
    throw BluetoothConnectException(
      '페어링된 기기 중 "$deviceName"을(를) 찾을 수 없습니다. '
      '휴대폰 블루투스 설정에서 먼저 페어링해 주세요.',
    );
  }

  /// AGV 전원 꺼짐/거리 이탈 등으로 상대 쪽에서 연결이 끊긴 경우.
  void _handleRemoteClosed() {
    if (_connectionStatus != ConnectionStatus.connected) return;
    _closeConnection();
    _setConnection(ConnectionStatus.disconnected);
  }

  Future<void> _closeConnection() async {
    final sub = _inputSub;
    final connection = _connection;
    _inputSub = null;
    _connection = null;
    _lineBuffer.clear();
    await sub?.cancel();
    try {
      await connection?.close();
    } catch (_) {
      // 이미 끊긴 소켓을 닫을 때의 예외는 무시.
    }
  }

  void _setConnection(ConnectionStatus status) {
    _connectionStatus = status;
    if (!_connectionController.isClosed) _connectionController.add(status);
  }
}

/// 원본 에러/스택트레이스를 디버그 빌드 콘솔에만 남긴다 (릴리스 빌드에서는 출력 안 함).
void logBluetoothError(String context, Object error, [StackTrace? stack]) {
  if (!kDebugMode) return;
  debugPrint('[Bluetooth] $context: $error');
  if (stack != null) debugPrint(stack.toString());
}

/// 화면 상단 에러 배너에 그대로 표시되는 연결 실패 사유.
/// 사용자가 읽을 짧은 문구만 담는다 (원본 예외 텍스트 금지).
class BluetoothConnectException implements Exception {
  const BluetoothConnectException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 휴대폰에 페어링된 블루투스 기기. UI가 플러그인 타입에 의존하지 않도록 분리.
@immutable
class PairedDevice {
  const PairedDevice({required this.name, required this.address});

  final String name;

  /// MAC 주소 (예: "98:D3:31:F5:12:AB")
  final String address;

  @override
  bool operator ==(Object other) =>
      other is PairedDevice && other.name == name && other.address == address;

  @override
  int get hashCode => Object.hash(name, address);
}

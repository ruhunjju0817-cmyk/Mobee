import '../models/agv_status.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

/// AGV 데이터 공급원 인터페이스.
///
/// UI/컨트롤러는 이 인터페이스에만 의존한다.
/// 현재는 [DummyAgvDataSource]를 사용하고, 추후 [BluetoothAgvDataSource]를
/// 구현하여 main.dart에서 교체하기만 하면 된다.
abstract class AgvDataSource {
  /// 화면에 표시할 데이터 소스 이름 (예: "DUMMY", "BLUETOOTH")
  String get name;

  /// 수신되는 AGV 상태 스트림.
  Stream<AgvStatus> get statusStream;

  /// 연결 상태 변경 스트림.
  Stream<ConnectionStatus> get connectionStream;

  ConnectionStatus get connectionStatus;

  Future<void> connect();

  Future<void> disconnect();

  /// 스트림 등 리소스 해제.
  void dispose();
}

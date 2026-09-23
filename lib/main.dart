import 'package:flutter/material.dart';

import 'controllers/monitor_controller.dart';
import 'screens/monitor_screen.dart';
import 'services/agv_data_source.dart';
import 'services/dummy_agv_data_source.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MobeeApp());
}

/// 사용할 데이터 소스를 생성한다.
///
/// Bluetooth 구현 후에는 이 함수만 바꾸면 된다:
/// ```dart
/// return BluetoothAgvDataSource(deviceName: 'MOBEE-AGV');
/// ```
AgvDataSource createDataSource() => DummyAgvDataSource();

class MobeeApp extends StatefulWidget {
  const MobeeApp({super.key, this.dataSource});

  /// 테스트 등에서 데이터 소스를 주입할 때 사용. null이면 [createDataSource].
  final AgvDataSource? dataSource;

  @override
  State<MobeeApp> createState() => _MobeeAppState();
}

class _MobeeAppState extends State<MobeeApp> {
  late final MonitorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MonitorController(widget.dataSource ?? createDataSource())
      ..start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZoneGuard Monitor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: MonitorScreen(controller: _controller),
    );
  }
}

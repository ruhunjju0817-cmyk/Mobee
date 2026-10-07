import 'package:flutter/material.dart';

import 'controllers/monitor_controller.dart';
import 'controllers/theme_controller.dart';
import 'screens/monitor_screen.dart';
import 'services/agv_data_source.dart';
import 'services/dummy_agv_data_source.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 첫 화면부터 저장된 테마로 그리도록 runApp 전에 불러온다.
  final theme = await ThemeController.load();
  runApp(MobeeApp(themeController: theme));
}

/// 사용할 데이터 소스를 생성한다.
///
/// Bluetooth 구현 후에는 이 함수만 바꾸면 된다:
/// ```dart
/// return BluetoothAgvDataSource(deviceName: 'MOBEE-AGV');
/// ```
AgvDataSource createDataSource() => DummyAgvDataSource();

class MobeeApp extends StatefulWidget {
  const MobeeApp({super.key, this.dataSource, this.themeController});

  /// 테스트 등에서 데이터 소스를 주입할 때 사용. null이면 [createDataSource].
  final AgvDataSource? dataSource;

  /// null이면 저장하지 않는 라이트 테마 컨트롤러를 사용 (테스트용).
  final ThemeController? themeController;

  @override
  State<MobeeApp> createState() => _MobeeAppState();
}

class _MobeeAppState extends State<MobeeApp> {
  late final MonitorController _controller;
  late final ThemeController _theme;

  @override
  void initState() {
    super.initState();
    _controller = MonitorController(widget.dataSource ?? createDataSource())
      ..start();
    _theme = widget.themeController ?? ThemeController();
  }

  @override
  void dispose() {
    _controller.dispose();
    if (widget.themeController == null) _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _theme,
      builder: (context, _) => MaterialApp(
        title: 'ZoneGuard Monitor',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _theme.mode,
        home: MonitorScreen(controller: _controller, theme: _theme),
      ),
    );
  }
}

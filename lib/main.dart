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
/// 실제 AGV(HC-05/06)로 전환하려면 아래 두 줄의 주석을 바꾸고,
/// 상단에 `import 'services/bluetooth_agv_data_source.dart';`를 추가한다.
/// deviceName은 휴대폰에 페어링된 블루투스 이름과 정확히 같아야 한다.
AgvDataSource createDataSource() => DummyAgvDataSource();
// AgvDataSource createDataSource() => BluetoothAgvDataSource(deviceName: 'HC-05');

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

import 'package:flutter/material.dart';

import 'controllers/connection_prefs.dart';
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
  final connectionPrefs = await ConnectionPrefs.load();
  runApp(MobeeApp(themeController: theme, connectionPrefs: connectionPrefs));
}

/// 앱 시작 시 데이터 소스. 항상 더미로 시작한다.
///
/// 블루투스(HC-05/06) 연결은 상단 연결 버튼의 시트에서 고르며,
/// 마지막으로 연결한 기기가 저장돼 있으면 시작 직후 자동 연결을 시도한다.
AgvDataSource createDataSource() => DummyAgvDataSource();

class MobeeApp extends StatefulWidget {
  const MobeeApp({
    super.key,
    this.dataSource,
    this.themeController,
    this.connectionPrefs,
  });

  /// 테스트 등에서 데이터 소스를 주입할 때 사용. null이면 [createDataSource].
  final AgvDataSource? dataSource;

  /// null이면 저장하지 않는 라이트 테마 컨트롤러를 사용 (테스트용).
  final ThemeController? themeController;

  /// 마지막 연결 기기 저장소. null이면 저장하지 않음 (자동 연결 없음, 테스트용).
  final ConnectionPrefs? connectionPrefs;

  @override
  State<MobeeApp> createState() => _MobeeAppState();
}

class _MobeeAppState extends State<MobeeApp> {
  late final MonitorController _controller;
  late final ThemeController _theme;

  @override
  void initState() {
    super.initState();
    _controller = MonitorController(
      widget.dataSource ?? createDataSource(),
      prefs: widget.connectionPrefs,
    );
    // 더미로 먼저 화면을 채운 뒤, 저장된 기기가 있으면 그쪽으로 연결 시도.
    _controller.start().then((_) => _controller.autoConnectLastDevice());
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

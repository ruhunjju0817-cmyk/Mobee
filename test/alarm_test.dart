import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobee/controllers/alarm_controller.dart';
import 'package:mobee/controllers/connection_prefs.dart';
import 'package:mobee/controllers/monitor_controller.dart';
import 'package:mobee/controllers/theme_controller.dart';
import 'package:mobee/models/agv_enums.dart';
import 'package:mobee/models/agv_status.dart';
import 'package:mobee/models/alarm.dart';
import 'package:mobee/screens/monitor_screen.dart';
import 'package:mobee/services/agv_packet_parser.dart';
import 'package:mobee/services/alarm_policy.dart';
import 'package:mobee/services/dummy_agv_data_source.dart';
import 'package:mobee/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

AgvStatus _p(String line) => AgvPacketParser.parse(line)!;

/// AppLifecycleListener는 실제 순서대로만 상태가 바뀌어야 한다.
void _toBackground(WidgetTester tester) {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

void _toForeground(WidgetTester tester) {
  for (final s in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

AlarmStage _stage(String line) => AlarmStage.of(_p(line));

void main() {
  group('경보 단계', () {
    test('대상: S=WARN/DANGER/BLOCK, H=COLLISION/TILT/LINE_LOST', () {
      expect(_stage('S=WARN'), AlarmStage.warning);
      expect(_stage('S=DANGER'), AlarmStage.danger);
      expect(_stage('S=BLOCK'), AlarmStage.blocked);
      expect(_stage('S=STOP;H=COLLISION'), AlarmStage.collision);
      expect(_stage('S=STOP;H=TILT'), AlarmStage.tilt);
      expect(_stage('S=STOP;H=LINE_LOST'), AlarmStage.lineLost);
    });

    test('대상 아님: NORMAL, STOP, Unknown, FRONT/SIDE만, 데이터 없음', () {
      expect(_stage('S=NORMAL'), AlarmStage.none);
      expect(_stage('S=STOP'), AlarmStage.none);
      expect(_stage('S=???'), AlarmStage.none);
      expect(_stage('S=NORMAL;H=FRONT,SIDE'), AlarmStage.none);
      expect(AlarmStage.of(AgvStatus.initial()), AlarmStage.none);
    });

    test('여러 개면 가장 나쁜 단계', () {
      expect(_stage('S=BLOCK;H=TILT'), AlarmStage.tilt);
      expect(_stage('S=DANGER;H=TILT,COLLISION'), AlarmStage.collision);
      expect(_stage('S=DANGER;H=LINE_LOST'), AlarmStage.danger);
      expect(_stage('S=WARN;H=LINE_LOST'), AlarmStage.lineLost);
    });

    test('나쁜 순서: 충돌 > 기울기 > 차단 > 위험 > 라인 이탈 > 주의 > 없음', () {
      const order = [
        AlarmStage.collision,
        AlarmStage.tilt,
        AlarmStage.blocked,
        AlarmStage.danger,
        AlarmStage.lineLost,
        AlarmStage.warning,
        AlarmStage.none,
      ];
      for (var i = 0; i < order.length - 1; i++) {
        expect(order[i].isWorseThan(order[i + 1]), isTrue);
        expect(order[i + 1].isWorseThan(order[i]), isFalse);
      }
    });

    test('진동: Warning 짧게 1, Danger 짧게 2, Blocked/충돌/기울기 길게 1', () {
      expect(AlarmStage.warning.vibration, AlarmVibration.shortOnce);
      expect(AlarmStage.danger.vibration, AlarmVibration.shortTwice);
      for (final s in [
        AlarmStage.blocked,
        AlarmStage.collision,
        AlarmStage.tilt,
      ]) {
        expect(s.vibration, AlarmVibration.long);
      }
      expect(AlarmStage.none.vibration, isNull);
      // 패턴 모양: [대기, 진동, ...] → 진동 횟수와 길이.
      expect(AlarmVibration.shortOnce.pattern, [0, 200]);
      expect(AlarmVibration.shortTwice.pattern, [0, 200, 150, 200]);
      expect(AlarmVibration.long.pattern, [0, 1000]);
    });

    test('배너 문구: "단계 · 이유"', () {
      String text(String line) {
        final s = _p(line);
        return AlarmEvent.from(s, AlarmStage.of(s), DateTime(2026)).text;
      }

      expect(text('S=DANGER;H=FRONT'), 'DANGER · 전방 장애물');
      expect(text('S=WARN;H=SIDE'), 'WARNING · 측면 사각지대');
      expect(text('S=WARN'), 'WARNING · 주의 필요');
      expect(text('S=BLOCK;H=FRONT'), 'BLOCKED · 전방 장애물');
      expect(text('S=STOP;H=COLLISION'), 'COLLISION · 정지');
      expect(text('S=STOP;H=COLLISION,FRONT'), 'COLLISION · 전방 장애물');
      expect(text('S=STOP;H=TILT'), 'TILT · 정지');
      expect(text('S=STOP;H=LINE_LOST'), 'LINE LOST · 정지');
    });
  });

  group('울림 규칙', () {
    final t0 = DateTime(2026, 11, 23, 10);
    DateTime at(double sec) =>
        t0.add(Duration(milliseconds: (sec * 1000).round()));

    test('나빠지는 순간에만 울림', () {
      final p = AlarmPolicy();
      expect(p.update(AlarmStage.none, at(0)), isFalse);
      expect(p.update(AlarmStage.warning, at(1)), isTrue);
      expect(p.update(AlarmStage.warning, at(2)), isFalse); // 같은 단계 유지
      expect(p.update(AlarmStage.warning, at(10)), isFalse); // 오래 지나도 유지면 X
      expect(p.update(AlarmStage.none, at(11)), isFalse); // 좋아짐
    });

    test('더 나쁜 단계로 바뀌면 바로 울림', () {
      final p = AlarmPolicy();
      expect(p.update(AlarmStage.warning, at(0)), isTrue);
      expect(p.update(AlarmStage.danger, at(0.5)), isTrue);
      expect(p.update(AlarmStage.collision, at(1)), isTrue);
      expect(p.update(AlarmStage.danger, at(1.5)), isFalse); // 좋아짐
    });

    test('같은 단계는 5초 안에 다시 울리지 않음', () {
      final p = AlarmPolicy();
      expect(p.update(AlarmStage.danger, at(0)), isTrue);
      p.update(AlarmStage.none, at(1));
      expect(p.update(AlarmStage.danger, at(4.9)), isFalse);
      p.update(AlarmStage.none, at(5));
      expect(p.update(AlarmStage.danger, at(5.0)), isTrue); // 5초 지남
    });

    test('쿨다운은 단계별: 방금 울린 단계보다 나쁜 단계는 바로', () {
      final p = AlarmPolicy();
      expect(p.update(AlarmStage.danger, at(0)), isTrue);
      p.update(AlarmStage.warning, at(1)); // 좋아짐
      expect(p.update(AlarmStage.danger, at(2)), isFalse); // Danger 쿨다운 중
      p.update(AlarmStage.none, at(2.5));
      expect(p.update(AlarmStage.warning, at(3)), isTrue); // Warning은 처음
      expect(p.update(AlarmStage.blocked, at(3.5)), isTrue);
    });
  });

  group('경보 컨트롤러', () {
    late DateTime now;
    late FakeAlarmOutput output;
    late List<FakeBluetoothSource> created;
    late MonitorController monitor;

    Future<AlarmController> setUpAlarm(
      WidgetTester tester, {
      AlarmSettings? settings,
      bool permission = true,
      bool hasVibrator = true,
    }) async {
      now = DateTime(2026, 11, 23, 10);
      output = FakeAlarmOutput(
        hasVibrator: hasVibrator,
        permissionGranted: permission,
      );
      created = [];
      monitor = MonitorController(
        DummyAgvDataSource(),
        prefs: ConnectionPrefs(),
        bluetoothSourceFactory: (name) {
          final s = FakeBluetoothSource(name);
          created.add(s);
          return s;
        },
        // 이 그룹은 경보만 본다 (데이터 끊김 타이머가 끼지 않게).
        staleTimeout: const Duration(days: 1),
      );
      final alarm = AlarmController(
        monitor: monitor,
        output: output,
        settings: settings,
        clock: () => now,
      );
      await tester.pumpWidget(const SizedBox());
      await alarm.start();
      await monitor.connectBluetooth('HC-05');
      await tester.pump();
      return alarm;
    }

    Future<void> send(WidgetTester tester, String line) async {
      created.single.emit(_p(line));
      await tester.pump();
    }

    void tearDownAlarm(AlarmController alarm) {
      alarm.dispose();
      monitor.dispose();
    }

    testWidgets('포그라운드: 진동 + 배너, 몇 초 뒤 배너 사라짐', (tester) async {
      final alarm = await setUpAlarm(tester);

      await send(tester, 'S=NORMAL');
      expect(output.vibrations, isEmpty);

      await send(tester, 'S=WARN;H=SIDE');
      expect(output.vibrations, [AlarmVibration.shortOnce]);
      expect(alarm.banner?.text, 'WARNING · 측면 사각지대');

      now = now.add(const Duration(seconds: 1));
      await send(tester, 'S=DANGER;H=FRONT');
      expect(output.vibrations.last, AlarmVibration.shortTwice);
      expect(alarm.banner?.text, 'DANGER · 전방 장애물');

      now = now.add(const Duration(seconds: 1));
      await send(tester, 'S=STOP;H=COLLISION');
      expect(output.vibrations.last, AlarmVibration.long);

      await tester.pump(alarm.bannerDuration);
      expect(alarm.banner, isNull);
      expect(output.notifications, isEmpty); // 포그라운드에서는 시스템 알림 X
      tearDownAlarm(alarm);
    });

    testWidgets('같은 상태 패킷이 계속 와도 한 번만 울림', (tester) async {
      final alarm = await setUpAlarm(tester);
      for (var i = 0; i < 10; i++) {
        now = now.add(const Duration(milliseconds: 200));
        await send(tester, 'S=DANGER;H=FRONT;F=15');
      }
      expect(output.vibrations, [AlarmVibration.shortTwice]);
      tearDownAlarm(alarm);
    });

    testWidgets('백그라운드: 시스템 알림 (진동 설정 포함), 배너/직접 진동 없음', (tester) async {
      final alarm = await setUpAlarm(tester);
      _toBackground(tester);

      await send(tester, 'S=BLOCK;H=FRONT');
      expect(output.notifications, hasLength(1));
      expect(output.notifications.single.event.text, 'BLOCKED · 전방 장애물');
      expect(output.notifications.single.vibrate, isTrue);
      expect(output.vibrations, isEmpty);
      expect(alarm.banner, isNull);

      _toForeground(tester);
      tearDownAlarm(alarm);
    });

    testWidgets('백그라운드 + 알림 권한 거부: 진동만', (tester) async {
      final alarm = await setUpAlarm(tester, permission: false);
      expect(alarm.notificationPermission, isFalse);
      _toBackground(tester);

      await send(tester, 'S=DANGER');
      expect(output.notifications, isEmpty);
      expect(output.vibrations, [AlarmVibration.shortTwice]);

      _toForeground(tester);
      tearDownAlarm(alarm);
    });

    testWidgets('알림 끔: 진동만 / 진동 끔: 배너만', (tester) async {
      final alarm = await setUpAlarm(tester);
      await alarm.setNotifyEnabled(false);
      await send(tester, 'S=WARN');
      expect(output.vibrations, [AlarmVibration.shortOnce]);
      expect(alarm.banner, isNull);

      await alarm.setNotifyEnabled(true);
      await alarm.setVibrateEnabled(false);
      now = now.add(const Duration(seconds: 1));
      await send(tester, 'S=DANGER');
      expect(output.vibrations, hasLength(1)); // 늘지 않음
      expect(alarm.banner?.stage, AlarmStage.danger);

      // 백그라운드 + 진동 끔 → 무음 채널 알림.
      _toBackground(tester);
      now = now.add(const Duration(seconds: 1));
      await send(tester, 'S=BLOCK');
      expect(output.notifications.single.vibrate, isFalse);
      _toForeground(tester);
      tearDownAlarm(alarm);
    });

    testWidgets('시작 시 알림 권한 요청, 알림 끔 상태면 요청 안 함', (tester) async {
      final on = await setUpAlarm(tester);
      expect(output.permissionRequests, 1);
      expect(on.notificationPermission, isTrue);
      tearDownAlarm(on);

      final off = await setUpAlarm(
        tester,
        settings: AlarmSettings(notifyEnabled: false),
      );
      expect(output.permissionRequests, 0);
      await off.setNotifyEnabled(true); // 켜는 순간 요청
      expect(output.permissionRequests, 1);
      tearDownAlarm(off);
    });

    testWidgets('설정은 저장되고 다음 실행에 복원', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final saved = await AlarmSettings.load();
      expect((saved.notifyEnabled, saved.vibrateEnabled), (true, true));

      final alarm = await setUpAlarm(tester, settings: saved);
      await alarm.setVibrateEnabled(false);
      await alarm.setNotifyEnabled(false);
      final reloaded = await AlarmSettings.load();
      expect((reloaded.notifyEnabled, reloaded.vibrateEnabled), (false, false));
      tearDownAlarm(alarm);
    });

    testWidgets('진동 모터 없는 기기: 진동 호출 안 함', (tester) async {
      final alarm = await setUpAlarm(tester, hasVibrator: false);
      expect(alarm.hasVibrator, isFalse);
      await send(tester, 'S=DANGER');
      expect(output.vibrations, isEmpty);
      expect(alarm.banner, isNotNull);
      tearDownAlarm(alarm);
    });
  });

  testWidgets('더미 모드에서도 동작 (시연용 상태 버튼)', (tester) async {
    final output = FakeAlarmOutput();
    final monitor = MonitorController(DummyAgvDataSource());
    final alarm = AlarmController(monitor: monitor, output: output);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MonitorScreen(
          controller: monitor,
          theme: ThemeController(),
          alarm: alarm,
        ),
      ),
    );
    await monitor.start();
    await alarm.start();
    await tester.pump();
    expect(output.vibrations, isEmpty); // Normal로 시작

    // 하단 상태 바에서 Blocked 선택.
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('scenario-bar')),
        matching: find.text(DriveState.blocked.label),
      ),
    );
    await tester.pump();
    expect(output.vibrations, [AlarmVibration.long]);
    expect(find.byKey(const ValueKey('alarm-banner')), findsOneWidget);
    expect(find.text('BLOCKED · 전방 장애물'), findsOneWidget);

    // 배너를 탭하면 닫힘.
    await tester.tap(find.byKey(const ValueKey('alarm-banner')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('alarm-banner')), findsNothing);

    alarm.dispose();
    monitor.dispose();
  });

  testWidgets('앱바 메뉴로 알림/진동 켜기·끄기', (tester) async {
    final monitor = MonitorController(DummyAgvDataSource());
    final alarm = AlarmController(monitor: monitor, output: FakeAlarmOutput());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MonitorScreen(
          controller: monitor,
          theme: ThemeController(),
          alarm: alarm,
        ),
      ),
    );
    await alarm.start();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('alarm-button')));
    await tester.pumpAndSettle();
    expect(find.text('위험 알림'), findsOneWidget);
    expect(find.text('위험 단계별 진동'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('alarm-toggle-vibrate')));
    await tester.pumpAndSettle();
    expect(alarm.vibrateEnabled, isFalse);
    expect(alarm.notifyEnabled, isTrue);

    await tester.tap(find.byKey(const ValueKey('alarm-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('alarm-toggle-notify')));
    await tester.pumpAndSettle();
    expect(alarm.notifyEnabled, isFalse);

    alarm.dispose();
    monitor.dispose();
  });

  testWidgets('360dp 앱바: 알림 버튼 추가 후에도 overflow 없음', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final monitor = MonitorController(
      DummyAgvDataSource(),
      prefs: ConnectionPrefs(),
      bluetoothSourceFactory: (name) => FakeBluetoothSource(name, fail: true),
    );
    final alarm = AlarmController(monitor: monitor, output: FakeAlarmOutput());
    await monitor.start();
    await monitor.connectBluetooth('HC-05'); // 가장 긴 "BLUETOOTH 연결 실패" 배지
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MonitorScreen(
          controller: monitor,
          theme: ThemeController(),
          alarm: alarm,
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('alarm-button')), findsOneWidget);
    expect(find.text('BT'), findsOneWidget); // 좁은 화면 축약
    expect(find.text('연결 실패'), findsOneWidget); // 상태 문구는 유지
    expect(tester.takeException(), isNull);
    alarm.dispose();
    monitor.dispose();
  });
}

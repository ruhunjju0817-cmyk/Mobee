import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

import '../models/alarm.dart';

/// 진동/시스템 알림 출력. 테스트에서는 가짜 구현으로 바꾼다.
abstract class AlarmOutput {
  /// 초기화. 진동 지원 여부를 돌려준다.
  Future<bool> init();

  /// Android 13+ 알림 권한 요청. 허용(또는 13 미만)이면 true.
  Future<bool> requestNotificationPermission();

  Future<void> vibrate(AlarmVibration vibration);

  /// 안드로이드 시스템 알림. [vibrate]가 true면 단계별 진동 채널로 보낸다.
  Future<void> showSystemNotification(
    AlarmEvent event, {
    required bool vibrate,
  });
}

/// 실제 기기용 구현 (vibration + flutter_local_notifications + permission_handler).
///
/// 플러그인 오류는 앱을 멈추지 않도록 모두 삼키고 디버그 로그로만 남긴다.
/// Android가 아니면(데스크톱 테스트 실행 등) 아무것도 하지 않는다.
class PlatformAlarmOutput implements AlarmOutput {
  final bool _enabled = !kIsWeb && Platform.isAndroid;

  final _notifications = FlutterLocalNotificationsPlugin();
  bool _hasVibrator = false;
  bool _notificationsReady = false;

  /// 무음(진동 없음) 채널. 진동 끔 설정일 때 사용.
  static const _silentChannel = AndroidNotificationChannel(
    'alarm_silent',
    'AGV 경보 (진동 없음)',
    description: '진동을 끈 상태의 위험 상태 알림',
    importance: Importance.high,
    enableVibration: false,
  );

  /// 진동 패턴은 채널 생성 시 고정되므로 패턴별로 채널을 만든다.
  static AndroidNotificationChannel _vibrateChannel(AlarmVibration v) =>
      AndroidNotificationChannel(
        'alarm_${v.name}',
        switch (v) {
          AlarmVibration.shortOnce => 'AGV 경보 - 주의',
          AlarmVibration.shortTwice => 'AGV 경보 - 위험',
          AlarmVibration.long => 'AGV 경보 - 정지/충돌/기울기',
        },
        description: '위험 상태 알림',
        importance: Importance.high,
        enableVibration: true,
        vibrationPattern: Int64List.fromList(v.pattern),
      );

  @override
  Future<bool> init() async {
    if (!_enabled) return false;
    try {
      _hasVibrator = await Vibration.hasVibrator();
    } catch (e) {
      _log('진동 지원 확인 실패', e);
    }
    try {
      await _notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(_silentChannel);
      for (final v in AlarmVibration.values) {
        await android?.createNotificationChannel(_vibrateChannel(v));
      }
      _notificationsReady = true;
    } catch (e) {
      _log('알림 초기화 실패', e);
    }
    return _hasVibrator;
  }

  @override
  Future<bool> requestNotificationPermission() async {
    if (!_enabled) return false;
    try {
      // Android 12 이하는 런타임 권한이 없어 곧바로 granted.
      return (await Permission.notification.request()).isGranted;
    } catch (e) {
      _log('알림 권한 요청 실패', e);
      return false;
    }
  }

  @override
  Future<void> vibrate(AlarmVibration vibration) async {
    if (!_hasVibrator) return;
    try {
      await Vibration.vibrate(pattern: vibration.pattern);
    } catch (e) {
      _log('진동 실패', e);
    }
  }

  @override
  Future<void> showSystemNotification(
    AlarmEvent event, {
    required bool vibrate,
  }) async {
    if (!_notificationsReady) return;
    final vibration = event.stage.vibration;
    final channel = vibrate && vibration != null
        ? _vibrateChannel(vibration)
        : _silentChannel;
    try {
      await _notifications.show(
        // 같은 id로 덮어써서 알림이 쌓이지 않게 한다 (항상 최신 경보 1건).
        id: 1,
        title: 'MOBEE AGV ${event.stage.title}',
        body: event.reason,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            enableVibration: channel.enableVibration,
            vibrationPattern: channel.vibrationPattern,
          ),
        ),
      );
    } catch (e) {
      _log('알림 표시 실패', e);
    }
  }

  static void _log(String context, Object error) {
    if (kDebugMode) debugPrint('[Alarm] $context: $error');
  }
}

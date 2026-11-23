import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../controllers/alarm_controller.dart';
import '../controllers/monitor_controller.dart';
import '../controllers/theme_controller.dart';
import '../models/agv_enums.dart';
import '../models/alarm.dart';
import '../services/agv_data_source.dart';
import '../theme/app_theme.dart';
import '../theme/status_style.dart';
import '../widgets/connection_sheet.dart';
import '../widgets/dashboard_background.dart';
import '../widgets/drive_state_card.dart';
import '../widgets/hazard_card.dart';
import '../widgets/sensor_card.dart';
import '../widgets/zone_card.dart';

/// ZoneGuard Monitor 메인 대시보드.
class MonitorScreen extends StatelessWidget {
  const MonitorScreen({
    super.key,
    required this.controller,
    required this.theme,
    this.alarm,
  });

  final MonitorController controller;
  final ThemeController theme;

  /// 위험 상태 경보 (배너 + 앱바 알림/진동 버튼). null이면 경보 UI 없음.
  final AlarmController? alarm;

  static const _wideBreakpoint = 720.0;
  static const _gap = 16.0;

  @override
  Widget build(BuildContext context) {
    final alarm = this.alarm;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, ?alarm]),
      builder: (context, _) {
        final p = context.palette;
        final status = controller.status;
        // 폰 세로 화면: 앱바 버튼 간격을 줄인다 (배지도 소스 이름을 축약).
        final narrow = MediaQuery.sizeOf(context).width < 400;

        return DashboardBackground(
          child: Scaffold(
            // 하단 바 뒤로 콘텐츠가 비치도록 body를 확장.
            extendBody: true,
            appBar: AppBar(
              toolbarHeight: 68,
              titleSpacing: 20,
              title: const _Title(),
              actions: [
                _ConnectionBadge(
                  sourceName: controller.sourceName,
                  connection: controller.connection,
                  onReconnect: controller.start,
                ),
                SizedBox(width: narrow ? 6 : 10),
                _ConnectionButton(controller: controller),
                if (alarm != null) ...[
                  SizedBox(width: narrow ? 6 : 8),
                  _AlarmButton(alarm: alarm),
                ],
                SizedBox(width: narrow ? 6 : 8),
                _ThemeToggle(theme: theme),
                SizedBox(width: narrow ? 12 : 20),
              ],
            ),
            body: Stack(
              children: [
                SafeArea(
                  bottom: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final zone = ZoneCard(zone: status.zone);
                      final drive = DriveStateCard(state: status.driveState);
                      final hazard = HazardCard(status: status);
                      final sensor = SensorCard(
                        sensors: status.sensors,
                        hasData: status.hasData,
                      );
                      const gap = SizedBox(width: _gap, height: _gap);

                      final content = constraints.maxWidth >= _wideBreakpoint
                          ? Column(
                              children: [
                                _pair(zone, drive),
                                gap,
                                _pair(hazard, sensor),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                zone,
                                gap,
                                drive,
                                gap,
                                hazard,
                                gap,
                                sensor,
                              ],
                            );

                      // extendBody 상태에서 하단 inset = 하단 바 높이.
                      final bottomInset = MediaQuery.paddingOf(context).bottom;

                      return SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          8,
                          20,
                          bottomInset + 24,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (controller.errorMessage != null)
                                  _ErrorBanner(
                                    message: controller.errorMessage!,
                                  ),
                                if (controller.isStale)
                                  _StaleBanner(
                                    lastUpdate: status.hasData
                                        ? status.timestamp
                                        : null,
                                  ),
                                // 패킷이 끊기면 마지막 값을 흐리게 보여 현재 값이 아님을 표시.
                                AnimatedOpacity(
                                  key: const ValueKey('dashboard-content'),
                                  opacity: controller.isStale ? 0.35 : 1,
                                  duration: const Duration(milliseconds: 250),
                                  child: content,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'LAST UPDATE   ${status.hasData ? _formatTime(status.timestamp) : '--:--:--'}',
                                  textAlign: TextAlign.center,
                                  style: AppText.label(p).copyWith(
                                    color: p.textMuted,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // 위험 상태 경보 배너 (몇 초 뒤 자동으로 사라짐).
                if (alarm != null)
                  Positioned(
                    top: 8,
                    left: 16,
                    right: 16,
                    child: _AlarmBanner(
                      event: alarm.banner,
                      onDismiss: alarm.dismissBanner,
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: controller.canSimulate
                ? _ScenarioBar(
                    key: const ValueKey('scenario-bar'),
                    current: status.driveState,
                    onSelected: controller.setScenario,
                  )
                : null,
          ),
        );
      },
    );
  }

  static Widget _pair(Widget a, Widget b) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: a),
          const SizedBox(width: _gap),
          Expanded(child: b),
        ],
      ),
    );
  }

  static String _formatTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

class _Title extends StatelessWidget {
  const _Title();

  static const _logoSize = 40.0;
  static const _logoGap = 12.0;

  /// 글자를 보여줄 최소 폭. 이보다 좁으면 로고만, 로고도 안 들어가면 비운다.
  static const _minTextWidth = 48.0;

  @override
  Widget build(BuildContext context) {
    // 앱바 오른쪽 버튼이 많아 제목 자리가 좁아질 수 있으므로 폭에 맞춰 줄인다.
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w < _logoSize) return const SizedBox.shrink();
        final showText = w >= _logoSize + _logoGap + _minTextWidth;
        return _buildRow(context, showText: showText);
      },
    );
  }

  Widget _buildRow(BuildContext context, {required bool showText}) {
    final p = context.palette;
    return Row(
      children: [
        Container(
          width: _logoSize,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                p.accent.withValues(alpha: 0.35),
                p.accent.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.accent.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(color: p.glow(p.accent, 0.2), blurRadius: 14),
            ],
          ),
          child: Icon(Icons.shield_moon_rounded, color: p.accent, size: 22),
        ),
        if (showText) ...[
          const SizedBox(width: _logoGap),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ZoneGuard Monitor',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'MOBEE AGV · 실시간 모니터링',
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label(p).copyWith(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: p.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 데이터 소스 이름 + 연결 상태(연결 중/연결됨/끊김/연결 실패) 표시.
/// 끊김·실패 상태에서 탭하면 다시 연결한다.
class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({
    required this.sourceName,
    required this.connection,
    required this.onReconnect,
  });

  final String sourceName;
  final ConnectionStatus connection;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // 좁은 화면(폰 세로)에서는 앱바 버튼이 많아 소스 이름을 줄여 쓴다.
    final narrow = MediaQuery.sizeOf(context).width < 400;
    final shownName = narrow && sourceName == 'BLUETOOTH' ? 'BT' : sourceName;
    final label = connection.label;
    final color = switch (connection) {
      ConnectionStatus.connected => AppColors.safe,
      ConnectionStatus.connecting => AppColors.warning,
      ConnectionStatus.error => AppColors.danger,
      ConnectionStatus.disconnected => AppColors.inactive,
    };
    final canReconnect =
        connection == ConnectionStatus.disconnected ||
        connection == ConnectionStatus.error;
    final badge = Container(
      key: const ValueKey('connection-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: p.glow(color, 0.5), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            shownName,
            style: AppText.label(p).copyWith(
              color: p.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppText.label(
              p,
            ).copyWith(color: color, fontWeight: FontWeight.w700),
          ),
          if (canReconnect) ...[
            const SizedBox(width: 4),
            Icon(Icons.refresh_rounded, size: 14, color: color),
          ],
        ],
      ),
    );
    if (!canReconnect) return badge;
    return Tooltip(
      message: '다시 연결',
      child: GestureDetector(onTap: onReconnect, child: badge),
    );
  }
}

/// 연결 시트를 여는 버튼. 아이콘으로 현재 소스/연결 상태를 함께 보여준다.
class _ConnectionButton extends StatelessWidget {
  const _ConnectionButton({required this.controller});

  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (icon, color) = !controller.isBluetooth
        ? (Icons.bluetooth_rounded, p.textSecondary)
        : switch (controller.connection) {
            ConnectionStatus.connected => (
              Icons.bluetooth_connected_rounded,
              AppColors.safe,
            ),
            ConnectionStatus.connecting => (
              Icons.bluetooth_searching_rounded,
              AppColors.warning,
            ),
            ConnectionStatus.error => (
              Icons.bluetooth_disabled_rounded,
              AppColors.danger,
            ),
            ConnectionStatus.disconnected => (
              Icons.bluetooth_disabled_rounded,
              p.textMuted,
            ),
          };
    return Tooltip(
      message: '연결 관리',
      child: Material(
        color: p.surface,
        shape: CircleBorder(side: BorderSide(color: p.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('connection-button'),
          onTap: () => showConnectionSheet(context, controller),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

/// 알림/진동 켜기·끄기 메뉴 버튼. 아이콘으로 현재 설정을 보여준다.
class _AlarmButton extends StatelessWidget {
  const _AlarmButton({required this.alarm});

  final AlarmController alarm;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final notify = alarm.notifyEnabled;
    final vibrate = alarm.vibrateEnabled && alarm.hasVibrator;
    final icon = notify
        ? Icons.notifications_active_rounded
        : vibrate
        ? Icons.vibration_rounded
        : Icons.notifications_off_rounded;
    return Material(
      color: p.surface,
      shape: CircleBorder(side: BorderSide(color: p.border)),
      clipBehavior: Clip.antiAlias,
      child: PopupMenuButton<_AlarmToggle>(
        key: const ValueKey('alarm-button'),
        tooltip: '알림/진동 설정',
        position: PopupMenuPosition.under,
        onSelected: (t) => switch (t) {
          _AlarmToggle.notify => alarm.setNotifyEnabled(!alarm.notifyEnabled),
          _AlarmToggle.vibrate => alarm.setVibrateEnabled(
            !alarm.vibrateEnabled,
          ),
        },
        itemBuilder: (_) => [
          CheckedPopupMenuItem(
            key: const ValueKey('alarm-toggle-notify'),
            value: _AlarmToggle.notify,
            checked: alarm.notifyEnabled,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('위험 알림'),
              subtitle: Text(
                alarm.notifyEnabled && alarm.notificationPermission == false
                    ? '화면 배너만 표시 (시스템 알림 권한 없음)'
                    : '화면 배너 + 백그라운드 알림',
              ),
            ),
          ),
          CheckedPopupMenuItem(
            key: const ValueKey('alarm-toggle-vibrate'),
            value: _AlarmToggle.vibrate,
            checked: alarm.vibrateEnabled,
            enabled: alarm.hasVibrator,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('진동'),
              subtitle: Text(
                alarm.hasVibrator ? '위험 단계별 진동' : '이 기기는 진동을 지원하지 않습니다',
              ),
            ),
          ),
        ],
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(
            icon,
            size: 20,
            color: notify || vibrate ? p.accent : p.textMuted,
          ),
        ),
      ),
    );
  }
}

enum _AlarmToggle { notify, vibrate }

/// 화면 상단 경보 배너. [event]가 null이면 숨김. 탭하면 닫힌다.
class _AlarmBanner extends StatelessWidget {
  const _AlarmBanner({required this.event, required this.onDismiss});

  final AlarmEvent? event;
  final VoidCallback onDismiss;

  static Color colorOf(AlarmStage stage) => switch (stage) {
    AlarmStage.collision ||
    AlarmStage.tilt ||
    AlarmStage.blocked => AppColors.danger,
    AlarmStage.danger || AlarmStage.lineLost => AppColors.alert,
    AlarmStage.warning => AppColors.warning,
    AlarmStage.none => AppColors.inactive,
  };

  @override
  Widget build(BuildContext context) {
    final e = event;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween(
          begin: const Offset(0, -0.4),
          end: Offset.zero,
        ).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: e == null
          ? const SizedBox.shrink()
          : Center(
              key: ValueKey(e),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Material(
                  key: const ValueKey('alarm-banner'),
                  color: colorOf(e.stage),
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onDismiss,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_rounded,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              e.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// 라이트/다크 테마 전환 버튼. 전환될 테마의 아이콘을 보여준다.
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.theme});

  final ThemeController theme;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = theme.isDark;
    return Tooltip(
      message: dark ? '라이트 모드로 전환' : '다크 모드로 전환',
      child: Material(
        color: p.surface,
        shape: CircleBorder(side: BorderSide(color: p.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('theme-toggle'),
          onTap: theme.toggle,
          child: SizedBox(
            width: 38,
            height: 38,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => RotationTransition(
                turns: Tween(begin: 0.75, end: 1.0).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                key: ValueKey(dark),
                size: 20,
                color: dark ? AppColors.warning : p.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 하단 상태 선택 바 (더미 모드 전용). 반투명 블러 배경, 현재 상태는 글로우 강조.
class _ScenarioBar extends StatelessWidget {
  const _ScenarioBar({
    super.key,
    required this.current,
    required this.onSelected,
  });

  final DriveState current;
  final ValueChanged<DriveState> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: p.barBackground,
            border: Border(top: BorderSide(color: p.border)),
            boxShadow: [
              BoxShadow(
                color: p.shadow,
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      for (final s in DriveState.known) ...[
                        Expanded(
                          child: _ScenarioButton(
                            state: s,
                            selected: s == current,
                            onTap: () => onSelected(s),
                          ),
                        ),
                        if (s != DriveState.known.last)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScenarioButton extends StatelessWidget {
  const _ScenarioButton({
    required this.state,
    required this.selected,
    required this.onTap,
  });

  final DriveState state;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = state.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.16)
                : p.surfaceHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.9) : p.border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [BoxShadow(color: p.glow(color, 0.25), blurRadius: 14)]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                state.icon,
                size: 28,
                color: selected ? color : p.textMuted,
                // 다크 테마에서만 아이콘 글로우.
                shadows: selected && p.isDark
                    ? [
                        Shadow(
                          color: color.withValues(alpha: 0.8),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  state.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.4,
                    color: selected ? p.textPrimary : p.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 블루투스 연결은 유지되는데 패킷이 끊겼을 때의 배너.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.lastUpdate});

  /// null이면 연결 후 패킷을 한 번도 받지 못함.
  final DateTime? lastUpdate;

  @override
  Widget build(BuildContext context) {
    final last = lastUpdate;
    final detail = last == null
        ? '연결 후 아직 수신된 패킷이 없습니다.'
        : '아래는 마지막 수신 값입니다 (${MonitorScreen._formatTime(last)}).';
    return Container(
      key: const ValueKey('stale-banner'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.portable_wifi_off_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '데이터 없음 — 2초 넘게 AGV 패킷이 수신되지 않았습니다.\n$detail',
              style: const TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: _gapBelow),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(color: p.glow(AppColors.danger, 0.12), blurRadius: 14),
        ],
      ),
      child: Text(message, style: const TextStyle(color: AppColors.danger)),
    );
  }

  static const _gapBelow = 16.0;
}

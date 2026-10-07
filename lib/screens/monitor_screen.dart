import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../controllers/monitor_controller.dart';
import '../controllers/theme_controller.dart';
import '../models/agv_enums.dart';
import '../services/agv_data_source.dart';
import '../theme/app_theme.dart';
import '../theme/status_style.dart';
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
  });

  final MonitorController controller;
  final ThemeController theme;

  static const _wideBreakpoint = 720.0;
  static const _gap = 16.0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final p = context.palette;
        final status = controller.status;

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
                ),
                const SizedBox(width: 10),
                _ThemeToggle(theme: theme),
                const SizedBox(width: 20),
              ],
            ),
            body: SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final zone = ZoneCard(zone: status.zone);
                  final drive = DriveStateCard(state: status.driveState);
                  final hazard = HazardCard(status: status);
                  final sensor = SensorCard(sensors: status.sensors);
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
                    padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (controller.errorMessage != null)
                              _ErrorBanner(message: controller.errorMessage!),
                            content,
                            const SizedBox(height: 20),
                            Text(
                              'LAST UPDATE   ${_formatTime(status.timestamp)}',
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

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Container(
          width: 40,
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
        const SizedBox(width: 12),
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
                style: AppText.label(
                  p,
                ).copyWith(fontSize: 10, letterSpacing: 1, color: p.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.sourceName, required this.connection});

  final String sourceName;
  final ConnectionStatus connection;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = switch (connection) {
      ConnectionStatus.connected => AppColors.safe,
      ConnectionStatus.connecting => AppColors.warning,
      ConnectionStatus.error => AppColors.danger,
      ConnectionStatus.disconnected => AppColors.inactive,
    };
    return Container(
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
            sourceName,
            style: AppText.label(p).copyWith(
              color: p.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
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
                      for (final s in DriveState.values) ...[
                        Expanded(
                          child: _ScenarioButton(
                            state: s,
                            selected: s == current,
                            onTap: () => onSelected(s),
                          ),
                        ),
                        if (s != DriveState.values.last)
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

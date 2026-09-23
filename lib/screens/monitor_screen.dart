import 'package:flutter/material.dart';

import '../controllers/monitor_controller.dart';
import '../models/agv_enums.dart';
import '../services/agv_data_source.dart';
import '../theme/app_theme.dart';
import '../theme/status_style.dart';
import '../widgets/drive_state_card.dart';
import '../widgets/hazard_card.dart';
import '../widgets/sensor_card.dart';
import '../widgets/zone_card.dart';

/// ZoneGuard Monitor 메인 대시보드.
class MonitorScreen extends StatelessWidget {
  const MonitorScreen({super.key, required this.controller});

  final MonitorController controller;

  static const _wideBreakpoint = 720.0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final status = controller.status;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: const _Title(),
            actions: [
              _ConnectionBadge(
                sourceName: controller.sourceName,
                connection: controller.connection,
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final zone = ZoneCard(zone: status.zone);
                final drive = DriveStateCard(state: status.driveState);
                final hazard = HazardCard(status: status);
                final sensor = SensorCard(sensors: status.sensors);
                const gap = SizedBox(width: 12, height: 12);

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
                        children: [zone, gap, drive, gap, hazard, gap, sensor],
                      );

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (controller.errorMessage != null)
                            _ErrorBanner(message: controller.errorMessage!),
                          content,
                          const SizedBox(height: 12),
                          Text(
                            '마지막 수신  ${_formatTime(status.timestamp)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
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
          const SizedBox(width: 12),
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
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
          ),
          child: const Icon(
            Icons.shield_moon_rounded,
            color: AppColors.accent,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        const Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ZoneGuard Monitor',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Text(
                'MOBEE AGV · 실시간 모니터링',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
    final color = switch (connection) {
      ConnectionStatus.connected => AppColors.safe,
      ConnectionStatus.connecting => AppColors.warning,
      ConnectionStatus.error => AppColors.danger,
      ConnectionStatus.disconnected => AppColors.inactive,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            sourceName,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 하단 상태 선택 바 (더미 모드 전용). 현재 상태를 강조 표시.
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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                    if (s != DriveState.values.last) const SizedBox(width: 6),
                  ],
                ],
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
    final color = state.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.22)
                : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                state.icon,
                size: 20,
                color: selected ? color : AppColors.textSecondary,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  state.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.danger)),
    );
  }
}

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
        final next = controller.nextSimulatedState;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: const _Title(),
            actions: [
              _ConnectionBadge(
                sourceName: controller.sourceName,
                connection: controller.connection,
              ),
              if (controller.canSimulate)
                PopupMenuButton<DriveState>(
                  tooltip: '상태 직접 선택',
                  icon: const Icon(Icons.tune_rounded),
                  onSelected: controller.setScenario,
                  itemBuilder: (context) => [
                    for (final s in DriveState.values)
                      PopupMenuItem(
                        value: s,
                        child: Row(
                          children: [
                            Icon(s.icon, color: s.color, size: 18),
                            const SizedBox(width: 10),
                            Text(s.label),
                          ],
                        ),
                      ),
                  ],
                ),
              const SizedBox(width: 8),
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
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
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: next == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: controller.cycleScenario,
                  icon: const Icon(Icons.sync_rounded),
                  label: Text('상태 전환  →  ${next.label}'),
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
          child: const Icon(Icons.shield_moon_rounded,
              color: AppColors.accent, size: 20),
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

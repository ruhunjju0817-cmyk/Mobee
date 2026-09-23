import 'package:flutter/material.dart';

import '../models/agv_enums.dart';
import '../theme/app_theme.dart';
import '../theme/status_style.dart';
import 'section_card.dart';

/// ② AGV 주행 상태.
class DriveStateCard extends StatelessWidget {
  const DriveStateCard({super.key, required this.state});

  final DriveState state;

  @override
  Widget build(BuildContext context) {
    final color = state.color;
    return SectionCard(
      index: 2,
      title: 'AGV 주행 상태',
      icon: Icons.precision_manufacturing_rounded,
      highlightColor: state == DriveState.normal ? null : color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(state.icon, color: color, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.label.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      state.description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in DriveState.values)
                _StateChip(state: s, active: s == state),
            ],
          ),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state, required this.active});

  final DriveState state;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = state.color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.2) : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? color : AppColors.border),
      ),
      child: Text(
        state.label,
        style: TextStyle(
          color: active ? color : AppColors.textSecondary,
          fontSize: 11,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

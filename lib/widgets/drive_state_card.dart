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
    final p = context.palette;
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
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.8)),
                  boxShadow: [
                    BoxShadow(color: p.glow(color, 0.25), blurRadius: 16),
                  ],
                ),
                child: Icon(state.icon, color: color, size: 30),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      strutStyle: AppText.strut(32),
                      style: AppText.value(p, color, size: 32),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      state.description,
                      strutStyle: AppText.strut(13, 1.4),
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
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
    final p = context.palette;
    final color = state.color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.8) : p.border,
        ),
      ),
      child: Text(
        state.label,
        style: TextStyle(
          color: active ? color : p.textMuted,
          fontSize: 11,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

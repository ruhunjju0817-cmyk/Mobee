import 'package:flutter/material.dart';

import '../models/agv_enums.dart';
import '../models/agv_status.dart';
import '../theme/app_theme.dart';
import '../theme/status_style.dart';
import 'section_card.dart';

/// ③ 위험 상태 표시 (감지 건수 + 2x2 타일).
class HazardCard extends StatelessWidget {
  const HazardCard({super.key, required this.status});

  final AgvStatus status;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final count = status.hazards.length;
    final color = count == 0
        ? AppColors.safe
        : HazardType.frontObstacle.activeColor(status.driveState);
    return SectionCard(
      index: 3,
      title: '위험 상태',
      icon: Icons.shield_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$count',
                strutStyle: AppText.strut(40),
                style: AppText.value(p, color, size: 40),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    count == 0 ? '감지된 위험 없음' : '위험 요소 감지',
                    strutStyle: AppText.strut(13, 1.4),
                    style: TextStyle(
                      color: count == 0 ? p.textSecondary : color,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _row(HazardType.frontObstacle, HazardType.sideBlindSpot),
          const SizedBox(height: 10),
          _row(HazardType.collision, HazardType.tilt),
        ],
      ),
    );
  }

  Widget _row(HazardType a, HazardType b) {
    return Row(
      children: [
        Expanded(child: _tile(a)),
        const SizedBox(width: 10),
        Expanded(child: _tile(b)),
      ],
    );
  }

  Widget _tile(HazardType type) => _HazardTile(
    type: type,
    active: status.hasHazard(type),
    activeColor: type.activeColor(status.driveState),
  );
}

class _HazardTile extends StatelessWidget {
  const _HazardTile({
    required this.type,
    required this.active,
    required this.activeColor,
  });

  final HazardType type;
  final bool active;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = active ? activeColor : p.textMuted;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active
            ? activeColor.withValues(alpha: 0.12)
            : p.surfaceHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? activeColor.withValues(alpha: 0.8) : p.border,
        ),
        boxShadow: active
            ? [BoxShadow(color: p.glow(activeColor, 0.18), blurRadius: 14)]
            : null,
      ),
      child: Row(
        children: [
          Icon(type.icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  strutStyle: AppText.strut(13, 1.4),
                  style: TextStyle(
                    color: active ? p.textPrimary : p.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  active ? '감지됨' : '정상',
                  strutStyle: AppText.strut(11, 1.4),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

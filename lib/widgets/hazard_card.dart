import 'package:flutter/material.dart';

import '../models/agv_enums.dart';
import '../models/agv_status.dart';
import '../theme/app_theme.dart';
import '../theme/status_style.dart';
import 'section_card.dart';

/// ③ 위험 상태 표시 (2x2 타일).
class HazardCard extends StatelessWidget {
  const HazardCard({super.key, required this.status});

  final AgvStatus status;

  @override
  Widget build(BuildContext context) {
    final count = status.hazards.length;
    return SectionCard(
      index: 3,
      title: '위험 상태',
      icon: Icons.shield_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            count == 0 ? '감지된 위험 없음' : '위험 요소 $count건 감지',
            style: TextStyle(
              color: count == 0
                  ? AppColors.safe
                  : HazardType.frontObstacle.activeColor(status.driveState),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _row(HazardType.frontObstacle, HazardType.sideBlindSpot),
          const SizedBox(height: 8),
          _row(HazardType.collision, HazardType.tilt),
        ],
      ),
    );
  }

  Widget _row(HazardType a, HazardType b) {
    return Row(
      children: [
        Expanded(child: _tile(a)),
        const SizedBox(width: 8),
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
    final color = active ? activeColor : AppColors.inactive;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: active
            ? activeColor.withValues(alpha: 0.16)
            : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? activeColor : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(type.icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  active ? '감지됨' : '정상',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

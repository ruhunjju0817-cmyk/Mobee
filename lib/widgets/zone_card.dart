import 'package:flutter/material.dart';

import '../models/agv_enums.dart';
import '../theme/app_theme.dart';
import '../theme/status_style.dart';
import 'section_card.dart';

/// ① 현재 Zone 표시.
class ZoneCard extends StatelessWidget {
  const ZoneCard({super.key, required this.zone});

  final AgvZone zone;

  static const _mapZones = [AgvZone.zone1, AgvZone.zone2, AgvZone.zone3];

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      index: 1,
      title: '현재 ZONE',
      icon: Icons.location_on_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 폰트(한글 fallback 등)에 따라 intrinsic/실제 높이가 달라져
          // IntrinsicHeight 안에서 1px overflow가 나지 않도록 줄 높이를 고정.
          Text(
            zone.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            strutStyle: const StrutStyle(
              fontSize: 34,
              height: 1.2,
              forceStrutHeight: true,
            ),
            style: TextStyle(
              color: zone.color,
              fontSize: 34,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            zone == AgvZone.unknown ? '위치 확인 불가' : '구역 내 주행 중',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            strutStyle: const StrutStyle(
              fontSize: 13,
              height: 1.4,
              forceStrutHeight: true,
            ),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final z in _mapZones) ...[
                Expanded(child: _ZoneCell(zone: z, active: z == zone)),
                if (z != _mapZones.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ZoneCell extends StatelessWidget {
  const _ZoneCell({required this.zone, required this.active});

  final AgvZone zone;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? AppColors.accent.withValues(alpha: 0.22)
            : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? AppColors.accent : AppColors.border,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (active) ...[
            const Icon(Icons.navigation_rounded,
                size: 14, color: AppColors.accent),
            const SizedBox(width: 4),
          ],
          Text(
            'Z${zone.code}',
            style: TextStyle(
              color: active ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

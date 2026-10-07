import 'package:flutter/material.dart';

import '../models/agv_enums.dart';
import '../theme/app_theme.dart';
import '../theme/status_style.dart';
import 'section_card.dart';

/// ① 현재 Zone 표시. 구역 번호를 크게 강조.
class ZoneCard extends StatelessWidget {
  const ZoneCard({super.key, required this.zone});

  final AgvZone zone;

  static const _mapZones = [AgvZone.zone1, AgvZone.zone2, AgvZone.zone3];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final known = zone != AgvZone.unknown;
    return SectionCard(
      index: 1,
      title: '현재 ZONE',
      icon: Icons.location_on_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                known ? '${zone.code}' : '–',
                strutStyle: AppText.strut(64, 1.05),
                style: AppText.value(p, zone.color(p), size: 64),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        known ? 'ZONE' : 'UNKNOWN',
                        strutStyle: AppText.strut(11, 1.4),
                        style: AppText.label(p),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        known ? '구역 내 주행 중' : '위치 확인 불가',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              for (final z in _mapZones) ...[
                Expanded(
                  child: _ZoneCell(zone: z, active: z == zone),
                ),
                if (z != _mapZones.last) const SizedBox(width: 10),
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
    final p = context.palette;
    final color = p.accent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      constraints: const BoxConstraints(minHeight: 42),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? color.withValues(alpha: 0.16)
            : p.surfaceHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? color : p.border,
          width: active ? 1.5 : 1,
        ),
        boxShadow: active
            ? [BoxShadow(color: p.glow(color, 0.2), blurRadius: 12)]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (active) ...[
            Icon(Icons.navigation_rounded, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            'Z${zone.code}',
            style: TextStyle(
              color: active ? p.textPrimary : p.textMuted,
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

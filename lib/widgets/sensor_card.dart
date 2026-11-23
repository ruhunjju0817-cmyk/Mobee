import 'package:flutter/material.dart';

import '../models/sensor_data.dart';
import '../theme/app_theme.dart';
import '../theme/status_style.dart';
import 'section_card.dart';

/// ④ 센서값 표시.
class SensorCard extends StatelessWidget {
  const SensorCard({super.key, required this.sensors, this.hasData = true});

  final SensorData sensors;

  /// false면 아직 패킷을 받지 않은 상태 → 모든 값을 "-"로 표시 ("미사용"과 구분).
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      index: 4,
      title: '센서값',
      icon: Icons.sensors_rounded,
      child: Column(
        children: [
          _SensorRow(
            hasData: hasData,
            icon: Icons.north_rounded,
            label: '정면 초음파',
            value: sensors.frontDistanceCm,
            unit: 'cm',
            max: 200,
            level: sensors.frontLevel,
          ),
          _SensorRow(
            hasData: hasData,
            icon: Icons.west_rounded,
            label: '좌측 ToF',
            value: sensors.leftDistanceCm,
            unit: 'cm',
            max: 50,
            level: sensors.leftLevel,
          ),
          _SensorRow(
            hasData: hasData,
            icon: Icons.east_rounded,
            label: '우측 초음파',
            value: sensors.rightDistanceCm,
            unit: 'cm',
            max: 50,
            level: sensors.rightLevel,
          ),
          _SensorRow(
            hasData: hasData,
            icon: Icons.straighten_rounded,
            label: 'IMU 기울기',
            value: sensors.tiltDeg,
            unit: '°',
            max: 20,
            level: sensors.tiltLevel,
          ),
          _SensorRow(
            hasData: hasData,
            icon: Icons.vibration_rounded,
            label: '진동',
            value: sensors.vibrationG,
            unit: 'g',
            max: 2,
            fractionDigits: 2,
            level: sensors.vibrationLevel,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _SensorRow extends StatelessWidget {
  const _SensorRow({
    required this.hasData,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.max,
    required this.level,
    this.fractionDigits = 1,
    this.isLast = false,
  });

  final IconData icon;
  final String label;

  final bool hasData;

  /// null이면 미사용 센서 (패킷에서 -1 또는 필드 없음). [hasData]가 false면 값 없음.
  final double? value;
  final String unit;

  /// 게이지 바의 최대값.
  final double max;
  final SensorLevel level;
  final int fractionDigits;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = level.color;
    final v = value;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: p.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  strutStyle: AppText.strut(12, 1.4),
                  style: TextStyle(
                    color: p.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              if (v == null)
                Text(
                  hasData ? '미사용' : '-',
                  strutStyle: AppText.strut(20),
                  style: TextStyle(
                    color: p.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Text(
                  v.toStringAsFixed(fractionDigits),
                  strutStyle: AppText.strut(20),
                  style: AppText.value(p, color, size: 20),
                ),
              const SizedBox(width: 4),
              SizedBox(
                width: 22,
                child: Text(v == null ? '' : unit, style: AppText.unit(p)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Gauge(
            fraction: v == null ? 0 : (v / max).clamp(0.0, 1.0),
            color: color,
          ),
        ],
      ),
    );
  }
}

/// 얇고 둥근 게이지 바. 채워진 부분은 그라데이션 + 글로우.
class _Gauge extends StatelessWidget {
  const _Gauge({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  static const _height = 4.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: _height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surfaceHigh,
          borderRadius: BorderRadius.circular(_height),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: fraction),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_height),
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.45), color],
                ),
                boxShadow: [
                  BoxShadow(color: p.glow(color, 0.3), blurRadius: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

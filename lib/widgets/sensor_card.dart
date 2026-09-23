import 'package:flutter/material.dart';

import '../models/sensor_data.dart';
import '../theme/app_theme.dart';
import '../theme/status_style.dart';
import 'section_card.dart';

/// ④ 센서값 표시.
class SensorCard extends StatelessWidget {
  const SensorCard({super.key, required this.sensors});

  final SensorData sensors;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      index: 4,
      title: '센서값',
      icon: Icons.sensors_rounded,
      child: Column(
        children: [
          _SensorRow(
            icon: Icons.north_rounded,
            label: '전방 거리',
            value: sensors.frontDistanceCm,
            unit: 'cm',
            max: 200,
            level: sensors.frontLevel,
          ),
          _SensorRow(
            icon: Icons.west_rounded,
            label: '좌측 거리',
            value: sensors.leftDistanceCm,
            unit: 'cm',
            max: 100,
            level: sensors.leftLevel,
          ),
          _SensorRow(
            icon: Icons.east_rounded,
            label: '우측 거리',
            value: sensors.rightDistanceCm,
            unit: 'cm',
            max: 100,
            level: sensors.rightLevel,
          ),
          _SensorRow(
            icon: Icons.straighten_rounded,
            label: 'IMU 기울기',
            value: sensors.tiltDeg,
            unit: '°',
            max: 20,
            level: sensors.tiltLevel,
          ),
          _SensorRow(
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
  final double value;
  final String unit;

  /// 게이지 바의 최대값.
  final double max;
  final SensorLevel level;
  final int fractionDigits;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = level.color;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                value.toStringAsFixed(fractionDigits),
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 3),
              SizedBox(
                width: 22,
                child: Text(
                  unit,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (value / max).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 400),
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                color: color,
                backgroundColor: AppColors.surfaceHigh,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

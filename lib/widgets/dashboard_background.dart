import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 대시보드 배경: 세로 그라데이션 + 상단 액센트 글로우 + 미세한 그리드.
class DashboardBackground extends StatelessWidget {
  const DashboardBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.background, p.backgroundDeep],
        ),
      ),
      child: CustomPaint(
        painter: _GridPainter(p.accent.withValues(alpha: 0.05)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.6, -1.1),
              radius: 1.2,
              colors: [p.glow(p.accent, 0.06), p.accent.withValues(alpha: 0)],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.color);

  final Color color;

  static const _spacing = 32.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += _spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += _spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => oldDelegate.color != color;
}

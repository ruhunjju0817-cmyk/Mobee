import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 대시보드 공통 카드 (번호 + 제목 헤더).
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.index,
    required this.title,
    required this.icon,
    required this.child,
    this.highlightColor,
  });

  final int index;
  final String title;
  final IconData icon;
  final Widget child;

  /// 지정 시 카드 테두리를 해당 색으로 강조.
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlightColor?.withValues(alpha: 0.7) ?? AppColors.border,
          width: highlightColor != null ? 1.5 : 1,
        ),
        boxShadow: highlightColor != null
            ? [
                BoxShadow(
                  color: highlightColor!.withValues(alpha: 0.18),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

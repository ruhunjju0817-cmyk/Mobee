import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 대시보드 공통 카드 (번호 + 제목 헤더).
///
/// 라이트: 흰 카드 + 연한 그림자, 다크: 반투명 카드 + 미세한 글로우.
/// [highlightColor] 지정 시 해당 색 테두리와 글로우로 강조.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.index,
    required this.title,
    required this.icon,
    required this.child,
    this.highlightColor,
    this.trailing,
  });

  final int index;
  final String title;
  final IconData icon;
  final Widget child;

  /// 지정 시 카드 테두리를 해당 색으로 강조.
  final Color? highlightColor;

  /// 헤더 오른쪽에 붙는 위젯 (상태 배지 등).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final highlight = highlightColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: highlight == null
            ? p.surface
            : Color.alphaBlend(highlight.withValues(alpha: 0.05), p.surface),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight?.withValues(alpha: 0.8) ?? p.border,
          width: highlight != null ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          if (highlight != null)
            BoxShadow(color: p.glow(highlight, 0.16), blurRadius: 22),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                index.toString().padLeft(2, '0'),
                style: AppText.label(
                  p,
                ).copyWith(color: p.accent, fontWeight: FontWeight.w700),
              ),
              Container(
                width: 1,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: p.border,
              ),
              Icon(icon, size: 15, color: p.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  strutStyle: AppText.strut(11, 1.4),
                  style: AppText.label(p),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

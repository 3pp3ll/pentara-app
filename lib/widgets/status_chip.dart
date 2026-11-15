import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// شارة حبّة بنص caption (12). لا تُنفخ إلى 44: ليست هدف لمس.
///
/// - شارات دلالية: حبر وخلفية من نبرة الحالة.
/// - [StatusChip.tag]: وسم وصفي بسطح وحد ونص inkMuted، بلا نبرة مخترعة
///   (مثل «وضع تجريبي — دون اتصال» و«آخر جلسة: $0.42»).
class StatusChip extends StatelessWidget {
  const StatusChip._({super.key, required this.label, this.tone});

  const StatusChip({
    Key? key,
    required String label,
    required StatusTone tone,
  }) : this._(key: key, label: label, tone: tone);

  const StatusChip.tag({
    Key? key,
    required String label,
  }) : this._(key: key, label: label);

  factory StatusChip.projectStatus(ProjectStatus s) =>
      StatusChip(label: s.label, tone: s.tone);

  factory StatusChip.readiness(ReadinessStage r) =>
      StatusChip(label: r.label, tone: r.tone);

  factory StatusChip.verdict(MessageVerdict v) =>
      StatusChip(label: v.label, tone: v.tone);

  final String label;

  /// null يعني وسماً وصفياً.
  final StatusTone? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = tone;
    final ink = t == null ? c.inkMuted : c.tone(t).ink;
    final bg = t == null ? c.surface : c.tone(t).bg;
    final side = t == null ? BorderSide(color: c.border) : BorderSide.none;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: bg,
        shape: StadiumBorder(side: side),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(color: ink),
        ),
      ),
    );
  }
}

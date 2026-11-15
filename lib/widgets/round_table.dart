import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'member_avatar.dart';

/// دائرة الطاولة بستة مقاعد. لا تقرأ AppState.
///
/// - الترتيب بالهوية الثابتة لا بترتيب القائمة: الرئيس أعلى، ثم مع عقارب
///   الساعة: المهندس، العملي، المحلل، المتحدّي، المدقق.
/// - الزاوية θ = −π/2 + i·π/3 في فضاء الشاشة (+Y نازل)، والمواضع بـ
///   Positioned(left/top) فلا يقلبها اتجاه RTL.
/// - المتحدث في المركز بقرص أكبر ونبض (pulsing). المقاعد isSpeaking: false
///   دائماً فتبقى بشفافية 0.85 دون نبض ثانٍ.
/// - side = min(قيد الأب، 288): لا يتجاوز قيد الأب أبداً.
class RoundTable extends StatelessWidget {
  const RoundTable({
    super.key,
    required this.members,
    required this.centerId,
    required this.pulsing,
  });

  final List<Member> members;
  final MemberId? centerId;
  final bool pulsing;

  static const List<MemberId> _seatOrder = [
    MemberId.chair,
    MemberId.engineer,
    MemberId.practical,
    MemberId.analyst,
    MemberId.challenger,
    MemberId.auditor,
  ];

  Member? _find(MemberId id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return LayoutBuilder(
      builder: (context, box) {
        final avail = box.maxWidth.isFinite ? box.maxWidth : 288.0;
        final side = math.min(avail, 288.0);
        final cx = side / 2;
        final cy = side / 2;

        final seatBox = (side * 0.2).clamp(40.0, 56.0).toDouble();
        final discR = seatBox * 0.66 / 2;
        final rSeat = side * 0.27;
        final centerBox = (side * 0.34).clamp(72.0, 100.0).toDouble();
        final labelW = side < 260 ? 52.0 : 60.0;
        const labelH = 18.0;

        final children = <Widget>[
          // سطح الطاولة: دائرة تمر بمراكز المقاعد.
          Positioned(
            left: cx - rSeat,
            top: cy - rSeat,
            width: rSeat * 2,
            height: rSeat * 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surfaceSoft,
                border: Border.all(color: c.border, width: 1),
              ),
            ),
          ),
        ];

        for (var i = 0; i < _seatOrder.length; i++) {
          final id = _seatOrder[i];
          final member = _find(id);
          if (member == null) continue;

          final theta = -math.pi / 2 + i * math.pi / 3;
          final dx = math.cos(theta);
          final dy = math.sin(theta);
          final sx = cx + rSeat * dx;
          final sy = cy + rSeat * dy;

          children.add(
            Positioned(
              left: sx - seatBox / 2,
              top: sy - seatBox / 2,
              width: seatBox,
              height: seatBox,
              child: MemberAvatar(member: member, size: seatBox),
            ),
          );

          // التسمية خارج القرص شعاعياً: المسافة تغطي نصف قطر القرص
          // وامتداد صندوق التسمية في الاتجاه نفسه، ثم تُقيَّد داخل المربع.
          final support = (labelW / 2) * dx.abs() + (labelH / 2) * dy.abs();
          final dist = rSeat + discR + 4 + support;
          final lx = (cx + dist * dx - labelW / 2)
              .clamp(0.0, math.max(0.0, side - labelW))
              .toDouble();
          final ly = (cy + dist * dy - labelH / 2)
              .clamp(0.0, math.max(0.0, side - labelH))
              .toDouble();

          final isCenter = id == centerId;
          children.add(
            Positioned(
              left: lx,
              top: ly,
              width: labelW,
              child: ExcludeSemantics(
                child: Text(
                  id == MemberId.chair ? 'الرئيس' : member.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: isCenter ? c.memberName(id) : c.inkMuted,
                  ),
                ),
              ),
            ),
          );
        }

        final centerMember = centerId == null ? null : _find(centerId!);
        children.add(
          Positioned(
            left: cx - centerBox / 2,
            top: cy - centerBox / 2,
            width: centerBox,
            height: centerBox,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              child: centerMember == null
                  ? const SizedBox.shrink(key: ValueKey('center-none'))
                  : MemberAvatar(
                      key: ValueKey('center-${centerMember.id.name}'),
                      member: centerMember,
                      size: centerBox,
                      isSpeaking: pulsing,
                    ),
            ),
          ),
        );

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              clipBehavior: Clip.none,
              children: children,
            ),
          ),
        );
      },
    );
  }
}

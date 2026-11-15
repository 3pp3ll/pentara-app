import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// الشريط السفلي. الترتيب من اليمين بلا عكس يدوي (RTL):
/// الرئيسية، الطاولة، المشاريع، المختبر، حسابي.
///
/// الهيكل: DecoratedBox(surface + حد علوي) ← SafeArea(top: false) ← صف.
/// كل عنصر بحد أدنى 72، فيتمدد مع تكبير الخط ولا يُصغَّر النص تحت 12.
/// خانة القرص 36 تُحجز دائماً: النشط قرص ذهبي (goldLight→gold500) بأيقونة
/// onGold، وغير النشط أيقونة inkMuted في الخانة نفسها فلا تقفز التسمية.
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<_NavSpec> _items = [
    _NavSpec('الرئيسية', _NavKind.home),
    _NavSpec('الطاولة', _NavKind.table),
    _NavSpec('المشاريع', _NavKind.projects),
    _NavSpec('المختبر', _NavKind.lab),
    _NavSpec('حسابي', _NavKind.account),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _NavItem(
                  spec: _items[i],
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _NavKind { home, table, projects, lab, account }

class _NavSpec {
  const _NavSpec(this.label, this.kind);

  final String label;
  final _NavKind kind;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _NavSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const duration = Duration(milliseconds: 300);
    const curve = Curves.easeOutCubic;

    final iconColor = selected ? AppColors.onGold : c.inkMuted;
    final textColor = selected ? c.goldText : c.inkMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: spec.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: c.goldLine.withAlpha(31),
        hoverColor: c.goldLine.withAlpha(31),
        focusColor: c.goldLine.withAlpha(31),
        splashColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: duration,
                    curve: curve,
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: selected
                          ? AppColors.discGradient(
                              AppColors.goldLight,
                              AppColors.gold500,
                            )
                          : null,
                    ),
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: iconColor),
                      duration: duration,
                      curve: curve,
                      builder: (context, value, _) => SizedBox(
                        width: 22,
                        height: 22,
                        child: CustomPaint(
                          painter: _NavIconPainter(
                            kind: spec.kind,
                            color: value ?? iconColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: duration,
                    curve: curve,
                    style: AppTypography.caption.copyWith(
                      color: textColor,
                      height: 1.3,
                    ),
                    child: Text(
                      spec.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// أيقونات مصمتة (fill) على شبكة 24×24: بيت، حلقة، مجلدان، أعمدة، شخص.
class _NavIconPainter extends CustomPainter {
  const _NavIconPainter({required this.kind, required this.color});

  final _NavKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    switch (kind) {
      case _NavKind.home:
        final house = Path()
          ..moveTo(12, 3)
          ..lineTo(22, 11.5)
          ..lineTo(20, 11.5)
          ..lineTo(20, 20)
          ..lineTo(14.5, 20)
          ..lineTo(14.5, 14.5)
          ..lineTo(9.5, 14.5)
          ..lineTo(9.5, 20)
          ..lineTo(4, 20)
          ..lineTo(4, 11.5)
          ..lineTo(2, 11.5)
          ..close();
        canvas.drawPath(house, fill);

      case _NavKind.table:
        final ring = Path()
          ..fillType = PathFillType.evenOdd
          ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 9.5))
          ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 5.5));
        canvas.drawPath(ring, fill);
        canvas.drawCircle(const Offset(12, 12), 2.2, fill);

      case _NavKind.projects:
        final back = Paint()
          ..color = color.withAlpha(150)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;
        canvas.drawRRect(
          RRect.fromLTRBR(7, 3, 21, 15, const Radius.circular(2.5)),
          back,
        );
        canvas.drawRRect(
          RRect.fromLTRBR(3, 8, 17, 21, const Radius.circular(2.5)),
          fill,
        );

      case _NavKind.lab:
        canvas.drawRRect(
          RRect.fromLTRBR(3, 13, 8, 21, const Radius.circular(1.5)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromLTRBR(9.5, 3, 14.5, 21, const Radius.circular(1.5)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromLTRBR(16, 8, 21, 21, const Radius.circular(1.5)),
          fill,
        );

      case _NavKind.account:
        canvas.drawCircle(const Offset(12, 8), 4.5, fill);
        final shoulders = Path()
          ..moveTo(4, 21)
          ..cubicTo(4, 15.5, 8, 14, 12, 14)
          ..cubicTo(16, 14, 20, 15.5, 20, 21)
          ..close();
        canvas.drawPath(shoulders, fill);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NavIconPainter old) =>
      old.kind != kind || old.color != color;
}

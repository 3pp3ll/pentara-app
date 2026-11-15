import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';

/// رمز العضو مرسوماً بـ CustomPainter على شبكة 24×24.
/// السماكة النسبية size × 0.085 (= 2.04 وحدة شبكة) مع أطراف مدوّرة.
/// زخرفي: لا يُقرأ مستقلاً (الوصف على القرص نفسه).
class MemberIcon extends StatelessWidget {
  const MemberIcon({
    super.key,
    required this.symbol,
    required this.size,
    required this.color,
  });

  final MemberSymbol symbol;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _MemberIconPainter(symbol: symbol, color: color),
        ),
      ),
    );
  }
}

class _MemberIconPainter extends CustomPainter {
  const _MemberIconPainter({required this.symbol, required this.color});

  final MemberSymbol symbol;
  final Color color;

  /// 24 × 0.085 وحدة شبكة، أي size × 0.085 بكسل بعد التحجيم.
  static const double _stroke = 2.04;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final soft = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    switch (symbol) {
      case MemberSymbol.crown:
        final crown = Path()
          ..moveTo(4.5, 16.5)
          ..lineTo(3.5, 8.5)
          ..lineTo(8.5, 12)
          ..lineTo(12, 6)
          ..lineTo(15.5, 12)
          ..lineTo(20.5, 8.5)
          ..lineTo(19.5, 16.5)
          ..close();
        canvas.drawPath(crown, fill);
        canvas.drawPath(crown, soft);
        canvas.drawRRect(
          RRect.fromLTRBR(4.5, 18.2, 19.5, 20.8, const Radius.circular(1.2)),
          fill,
        );

      case MemberSymbol.starburst8:
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          final outer = i.isEven ? 10.0 : 8.6;
          canvas.drawLine(
            Offset(12 + 4.2 * math.cos(a), 12 + 4.2 * math.sin(a)),
            Offset(12 + outer * math.cos(a), 12 + outer * math.sin(a)),
            line,
          );
        }
        canvas.drawCircle(const Offset(12, 12), 2.2, fill);

      case MemberSymbol.linkedRings:
        canvas.drawCircle(const Offset(9, 12), 5.2, line);
        canvas.drawCircle(const Offset(15, 12), 5.2, line);

      case MemberSymbol.star4:
        final star = Path();
        for (var i = 0; i < 8; i++) {
          final r = i.isEven ? 10.0 : 3.4;
          final a = -math.pi / 2 + i * math.pi / 4;
          final p = Offset(12 + r * math.cos(a), 12 + r * math.sin(a));
          if (i == 0) {
            star.moveTo(p.dx, p.dy);
          } else {
            star.lineTo(p.dx, p.dy);
          }
        }
        star.close();
        canvas.drawPath(star, fill);
        canvas.drawPath(star, soft);

      case MemberSymbol.crosshair:
        canvas.drawCircle(const Offset(12, 12), 6.5, line);
        canvas.drawLine(const Offset(12, 2.5), const Offset(12, 7), line);
        canvas.drawLine(const Offset(12, 17), const Offset(12, 21.5), line);
        canvas.drawLine(const Offset(2.5, 12), const Offset(7, 12), line);
        canvas.drawLine(const Offset(17, 12), const Offset(21.5, 12), line);
        canvas.drawCircle(const Offset(12, 12), 1.6, fill);

      case MemberSymbol.doubleDiamond:
        final outer = Path()
          ..moveTo(12, 3)
          ..lineTo(21, 12)
          ..lineTo(12, 21)
          ..lineTo(3, 12)
          ..close();
        final inner = Path()
          ..moveTo(12, 8)
          ..lineTo(16, 12)
          ..lineTo(12, 16)
          ..lineTo(8, 12)
          ..close();
        canvas.drawPath(outer, line);
        canvas.drawPath(inner, fill);
        canvas.drawPath(inner, soft);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MemberIconPainter old) =>
      old.symbol != symbol || old.color != color;
}

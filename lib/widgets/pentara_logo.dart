import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// شعار بنتارا: الوردة الخماسية + «بنتارا» + «PENTARA AI».
///
/// الافتراضي هو القفل الكامل. عند ضيق الرأس تُصغَّر العلامة ([markSize])
/// أو يُمرَّر showSubtitle: false، ولا يُصغَّر الخط عن 12.
class PentaraLogo extends StatelessWidget {
  const PentaraLogo({
    super.key,
    this.markSize = 48,
    this.showWordmark = true,
    this.showSubtitle = true,
  });

  final double markSize;
  final bool showWordmark;
  final bool showSubtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final mark = SizedBox(
      width: markSize,
      height: markSize,
      child: CustomPaint(painter: _PentaraMarkPainter(teal: c.teal)),
    );

    return Semantics(
      label: 'بنتارا Pentara AI',
      image: true,
      excludeSemantics: true,
      child: showWordmark
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                mark,
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'بنتارا',
                      style: AppTypography.wordmark.copyWith(color: c.ink),
                    ),
                    if (showSubtitle)
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          'PENTARA AI',
                          style: AppTypography.wordmarkLatin
                              .copyWith(color: c.goldText),
                        ),
                      ),
                  ],
                ),
              ],
            )
          : mark,
    );
  }
}

/// الوردة الخماسية داخل مربع 120 مُحجَّم بمعامل s = width / 120.
///
/// - كل بتلة قطع ناقص (26×50) مركزه (60,36) يُدوَّر هندسياً حول (60,60)
///   بـ Path.transform، ثم يُرسم بكانفس غير مدوَّر وتدرّج واحد ثابت على
///   مربع العلامة، فلا يدور الذهب مع البتلة.
/// - البتلات والحلقة حدود فقط (سماكة 3.2·s) بلا تعبئة.
/// - الحلقة التركوازية نصف قطرها 22·s: الموضع الوحيد لـ teal في التطبيق.
/// - النقطة بنصف قطر max(3.2·s, 2.0) بالبكسل المنطقي بعد التحجيم.
class _PentaraMarkPainter extends CustomPainter {
  const _PentaraMarkPainter({required this.teal});

  final Color teal;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120.0;
    final center = Offset(60 * s, 60 * s);
    final markRect = Offset.zero & size;
    final shader = AppColors.goldDiscGradient.createShader(markRect);

    final petalPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 * s
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // البتلة الأساسية بالنسبة للمركز: مركزها (0, 36−60) = (0, −24).
    final basePetal = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(0, -24 * s),
          width: 26 * s,
          height: 50 * s,
        ),
      );

    for (var i = 0; i < 5; i++) {
      final angle = i * 2 * math.pi / 5;
      final petal = basePetal
          .transform(Matrix4.rotationZ(angle).storage)
          .shift(center);
      canvas.drawPath(petal, petalPaint);
    }

    final ringPaint = Paint()
      ..color = teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 * s
      ..isAntiAlias = true;
    canvas.drawCircle(center, 22 * s, ringPaint);

    final dotPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(center, math.max(3.2 * s, 2.0), dotPaint);
  }

  @override
  bool shouldRepaint(covariant _PentaraMarkPainter old) => old.teal != teal;
}

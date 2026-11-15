import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'gold_button.dart';
import 'member_icons.dart';

/// تنبيه عام بألوان صريحة (لا snackBarTheme في الثيم): خلفية ink ونص bg.
/// يُعرض على سقالة الغلاف الواحدة فيظهر فوق الشريط السفلي.
void showPentaraToast(BuildContext context, String message) {
  final c = context.colors;
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(seconds: 3),
      content: Text(
        message,
        style: AppTypography.label.copyWith(color: c.bg),
      ),
    ),
  );
}

/// علامة صح مرسومة (خط) بلا إيموجي.
class CheckMarkIcon extends StatelessWidget {
  const CheckMarkIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _CheckPainter(color)),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.18, w * 0.55)
      ..lineTo(w * 0.42, w * 0.78)
      ..lineTo(w * 0.82, w * 0.26);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) => old.color != color;
}

/// بطاقة الخلاصة: حد goldLine بعرض 1px وظل ذهبي (الموضع الأول من موضعين
/// مسموحين). صف الجاهزية يُقرأ من [Summary.readiness]: المراحل حتى مرحلتها
/// مكتملة، واللاحقة على المسار الخافت.
///
/// - النسخ: ينتظر Clipboard.setData ثم يعرض التأكيد، والفشل يُلتقط ولا
///   يُعلَن نجاحاً.
/// - الحفظ: التأكيد يتبع القيمة العائدة من [onSave]، وهو حفظ داخل جلسة
///   التشغيل فقط.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.summary,
    required this.onSave,
  });

  final Summary summary;

  /// يعيد true عند نجاح الحفظ.
  final bool Function() onSave;

  String _plainText() =>
      [summary.title, ...summary.points.map((p) => '• $p')].join('\n');

  Future<void> _copy(BuildContext context) async {
    var ok = true;
    try {
      await Clipboard.setData(ClipboardData(text: _plainText()));
    } catch (_) {
      ok = false;
    }
    if (!context.mounted) return;
    showPentaraToast(context, ok ? 'تم نسخ الخلاصة' : 'تعذّر نسخ الخلاصة');
  }

  void _save(BuildContext context) {
    final ok = onSave();
    showPentaraToast(
      context,
      ok ? 'تم حفظ الخلاصة في هذه الجلسة' : 'الحفظ غير متاح الآن',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.goldLine, width: 1),
        boxShadow: AppColors.goldShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                MemberIcon(
                  symbol: MemberSymbol.crown,
                  size: 18,
                  color: c.goldText,
                ),
                const SizedBox(width: 8),
                Text(
                  'الخلاصة',
                  style: AppTypography.label.copyWith(color: c.goldText),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              summary.title,
              style: AppTypography.title.copyWith(color: c.ink),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < summary.points.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 11),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.gold500,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      summary.points[i],
                      style: AppTypography.body.copyWith(color: c.ink),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'الجاهزية',
              style: AppTypography.caption.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final stage in ReadinessStage.values)
                  _StageChip(
                    stage: stage,
                    reached: stage.index <= summary.readiness.index,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GoldButton.secondary(
                    label: 'نسخ',
                    expand: true,
                    onTap: () => _copy(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GoldButton.primary(
                    label: 'حفظ',
                    expand: true,
                    onTap: () => _save(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'يُحفظ داخل جلسة التشغيل فقط.',
              style: AppTypography.caption.copyWith(color: c.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.stage, required this.reached});

  final ReadinessStage stage;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = c.tone(stage.tone);
    final bg = reached ? tone.bg : c.track;
    final ink = reached ? tone.ink : c.inkMuted;

    return Semantics(
      label: '${stage.label}، ${reached ? 'مكتملة' : 'غير مكتملة'}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (reached) ...[
                CheckMarkIcon(size: 14, color: ink),
                const SizedBox(width: 6),
              ],
              Text(
                stage.label,
                maxLines: 1,
                style: AppTypography.caption.copyWith(color: ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

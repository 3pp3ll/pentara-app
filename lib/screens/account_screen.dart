import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/project_card.dart' show latinFigures;

/// حسابي: عرض فقط (بلا دفع ولا فتح روابط). بطاقة المستخدم كحلية من ألوان
/// الوضع الداكن في الوضعين.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final app = AppStateScope.of(context);
    final account = MockData.account;
    final credit = account.credit;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- الرأس: الصورة والاسم وID وزر المظهر
          Row(
            children: [
              const _Avatar(),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.displayName,
                      style: AppTypography.title.copyWith(color: c.ink),
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        'ID ${app.userId}',
                        style: latinFigures(AppTypography.caption)
                            .copyWith(color: c.inkMuted),
                      ),
                    ),
                  ],
                ),
              ),
              _ThemeToggle(isDark: app.isDark, onTap: app.toggleTheme),
            ],
          ),
          const SizedBox(height: 24),

          // ---- بطاقة المستخدم
          _UserCard(
            name: account.displayName,
            userId: app.userId,
            memberSince: app.memberSince,
            points: app.points,
          ),
          const SizedBox(height: 16),

          // ---- بطاقة الإحالة
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surfaceSoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.border, width: 1),
            ),
            child: Text(
              'ادعُ صديقاً: تحصل على \$5 من اشتراكه و500 نقطة، ويحصل هو على '
              '100 نقطة. إن اشترك في الباقة العليا تحصل على \$10 و1500 نقطة.',
              style: AppTypography.body.copyWith(color: c.ink),
            ),
          ),
          const SizedBox(height: 16),

          // ---- رصيد النماذج
          _CreditCard(credit: credit),
          const SizedBox(height: 24),

          // ---- الباقات
          Text('الباقات', style: AppTypography.title.copyWith(color: c.ink)),
          const SizedBox(height: 12),
          for (var i = 0; i < MockData.plans.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _PlanRow(plan: MockData.plans[i]),
          ],
          const SizedBox(height: 24),
          Center(
            child: Text(
              'عرض واجهة — بلا دفع',
              style: AppTypography.caption.copyWith(color: c.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.goldDiscGradient,
      ),
      child: ExcludeSemantics(
        child: CustomPaint(painter: _PersonPainter()),
      ),
    );
  }
}

class _PersonPainter extends CustomPainter {
  const _PersonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);
    final fill = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(const Offset(12, 9), 3.6, fill);
    final body = Path()
      ..moveTo(5.5, 19.5)
      ..cubicTo(5.5, 15.2, 8.5, 14, 12, 14)
      ..cubicTo(15.5, 14, 18.5, 15.2, 18.5, 19.5)
      ..close();
    canvas.drawPath(body, fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PersonPainter old) => false;
}

/// زر المظهر 44×44: أيقونة قمر/شمس فقط، يبدّل الوضع فعلاً.
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.isDark, required this.onTap});

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = isDark ? 'التبديل إلى الوضع الفاتح' : 'التبديل إلى الوضع الداكن';
    final overlay = c.goldLine.withAlpha(31);

    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            width: 44,
            height: 44,
            decoration: ShapeDecoration(
              color: c.surface,
              shape: CircleBorder(side: BorderSide(color: c.goldLine)),
            ),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              highlightColor: overlay,
              hoverColor: overlay,
              focusColor: overlay,
              splashColor: Colors.transparent,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CustomPaint(
                    painter: _ThemeIconPainter(
                      isDark: isDark,
                      color: c.goldText,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// في الوضع الداكن تظهر الشمس (للعودة للفاتح)، وفي الفاتح القمر.
class _ThemeIconPainter extends CustomPainter {
  const _ThemeIconPainter({required this.isDark, required this.color});

  final bool isDark;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    if (isDark) {
      canvas.drawCircle(const Offset(12, 12), 4.5, fill);
      final line = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;
      for (var i = 0; i < 8; i++) {
        final a = i * 3.141592653589793 / 4;
        final dx = _cos(a);
        final dy = _sin(a);
        canvas.drawLine(
          Offset(12 + 7.5 * dx, 12 + 7.5 * dy),
          Offset(12 + 10 * dx, 12 + 10 * dy),
          line,
        );
      }
    } else {
      final moon = Path()
        ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 8.5));
      final cut = Path()
        ..addOval(Rect.fromCircle(center: const Offset(16, 9), radius: 7));
      canvas.drawPath(
        Path.combine(PathOperation.difference, moon, cut),
        fill,
      );
    }
    canvas.restore();
  }

  static double _cos(double a) => _approx(a, true);
  static double _sin(double a) => _approx(a, false);

  static double _approx(double a, bool isCos) {
    // قيم مضبوطة للزوايا مضاعفات π/4 المستعملة فقط.
    const r = 0.7071067811865476;
    final k = (a / (3.141592653589793 / 4)).round() % 8;
    const cosT = [1.0, r, 0.0, -r, -1.0, -r, 0.0, r];
    const sinT = [0.0, r, 1.0, r, 0.0, -r, -1.0, -r];
    return isCos ? cosT[k] : sinT[k];
  }

  @override
  bool shouldRepaint(covariant _ThemeIconPainter old) =>
      old.isDark != isDark || old.color != color;
}

/// بطاقة المستخدم: تدرج كحلي من ألوان الوضع الداكن المعتمدة في الوضعين.
class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.name,
    required this.userId,
    required this.memberSince,
    required this.points,
  });

  final String name;
  final String userId;
  final String memberSince;
  final int points;

  static String _thousands(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    const d = PentaraColors.dark;
    final url = 'https://3pp3ll.github.io/pentara-app/?ref=$userId';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AppColors.disc145Begin,
          end: AppColors.disc145End,
          colors: [d.surface, d.bg],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: d.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.title.copyWith(color: d.ink)),
                const SizedBox(height: 4),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    'ID $userId',
                    style: latinFigures(AppTypography.label)
                        .copyWith(color: d.goldText),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'عضو منذ $memberSince',
                  style: AppTypography.caption.copyWith(color: d.inkMuted),
                ),
                const SizedBox(height: 12),
                Text('النقاط',
                    style: AppTypography.caption.copyWith(color: d.inkMuted)),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    _thousands(points),
                    style: AppTypography.metric.copyWith(color: d.goldText),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Semantics(
                  label: 'رمز QR لتحميل التطبيق',
                  child: QrImageView(
                    data: url,
                    size: 112,
                    padding: EdgeInsets.zero,
                    backgroundColor: const Color(0xFFFFFFFF),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'امسح لتحميل التطبيق',
                style: AppTypography.caption.copyWith(color: d.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// رصيد النماذج: بطاقة مختصرة (ارتفاع أدنى 96) بصف واحد وشريط.
class _CreditCard extends StatelessWidget {
  const _CreditCard({required this.credit});

  final CreditBalance credit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 96),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('رصيد النماذج',
                style: AppTypography.label.copyWith(color: c.inkMuted)),
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CreditItem(label: 'المتبقي', value: credit.remainingLabel),
                  _CreditItem(label: 'المستهلك', value: credit.consumedLabel),
                  _CreditItem(label: 'الحد', value: credit.limitLabel),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: c.track)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor:
                            credit.consumedFraction.clamp(0.0, 1.0).toDouble(),
                        heightFactor: 1,
                        child: const ColoredBox(color: AppColors.gold500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditItem extends StatelessWidget {
  const _CreditItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text(label,
              style: AppTypography.caption.copyWith(color: c.inkMuted)),
        ),
        Text(
          value,
          style: latinFigures(AppTypography.bodyStrong).copyWith(color: c.ink),
        ),
      ],
    );
  }
}

/// صف باقة مدمج. العليا وحدها بحد ذهبي وظل ذهبي وشارة.
class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final featured = plan.isFeatured;

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: featured ? c.goldLine : c.border,
          width: 1,
        ),
        boxShadow: featured ? AppColors.goldShadow : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(plan.name,
                          style:
                              AppTypography.bodyStrong.copyWith(color: c.ink)),
                    ),
                    if (plan.badgeText != null) ...[
                      const SizedBox(width: 8),
                      DecoratedBox(
                        decoration: ShapeDecoration(
                          color: c.surfaceSoft,
                          shape: StadiumBorder(
                              side: BorderSide(color: c.goldLine)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          child: Text(
                            plan.badgeText!,
                            style: AppTypography.caption
                                .copyWith(color: c.goldText),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (plan.quotaText != null)
                  Text(
                    plan.quotaText!,
                    style:
                        AppTypography.caption.copyWith(color: c.inkMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              plan.priceLabel,
              style: latinFigures(AppTypography.bodyStrong)
                  .copyWith(color: featured ? c.goldText : c.ink),
            ),
          ),
        ],
      ),
    );
  }
}

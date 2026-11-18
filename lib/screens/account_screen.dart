import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/glyph.dart';
import '../widgets/project_card.dart' show latinFigures;
import '../live/live_admin_screen.dart';
import '../live/live_account_card.dart';
import '../live/live_api.dart';
import '../widgets/share_card.dart';

/// حسابي. بطاقة المستخدم كحلية من ألوان
/// الوضع الداكن في الوضعين.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final app = AppStateScope.of(context);

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
                    ListenableBuilder(
                      listenable: LiveController.instance,
                      builder: (context, _) => Text(
                        LiveController.instance.displayName,
                        style: AppTypography.title.copyWith(color: c.ink),
                      ),
                    ),
                    // رقم الحساب يظهر بعد التسجيل فقط.
                    ListenableBuilder(
                      listenable: LiveController.instance,
                      builder: (context, _) {
                        final live = LiveController.instance;
                        final id = live.isRegistered ? live.user!.id : null;
                        if (id == null) {
                          return Text(
                            'زائر — سجّل لحفظ جلساتك',
                            style: AppTypography.caption.copyWith(color: c.inkMuted),
                          );
                        }
                        return Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            'ID $id',
                            style: latinFigures(AppTypography.caption)
                                .copyWith(color: c.inkMuted),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              _ThemeToggle(isDark: app.isDark, onTap: app.toggleTheme),
            ],
          ),
          const SizedBox(height: 24),

          // ---- بطاقة المستخدم + نص الإحالة (النص يُدار من لوحة التحكم على الويب)
          ListenableBuilder(
            listenable: LiveController.instance,
            builder: (context, _) {
              final live = LiveController.instance;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // البطاقة وQR تظهر بعد إنشاء الحساب فقط (الرابط مبني على ID الحقيقي).
                  if (live.isRegistered) ...[
                    _UserCard(
                      name: live.displayName,
                      userId: live.user!.id,
                      memberSince: app.memberSince,
                      points: app.points,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (live.referVisible && live.referText.trim().isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.surfaceSoft,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c.border, width: 1),
                      ),
                      child: Text(
                        live.referText,
                        style: AppTypography.body.copyWith(color: c.ink),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              );
            },
          ),


          // ---- الحساب الحقيقي: إنشاء، دخول، تفعيل كود المتجر
          const LiveAccountCard(),
          const SizedBox(height: 16),

          // ---- الباقات (يحددها المالك من لوحة التحكم: الاسم والسعر وما تشمله)
          Text('الباقات', style: AppTypography.title.copyWith(color: c.ink)),
          const SizedBox(height: 10),
          ListenableBuilder(
            listenable: LiveController.instance,
            builder: (context, _) {
              final plans = LiveController.instance.plans.isNotEmpty
                  ? LiveController.instance.plans
                  : _fallbackPlans;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < plans.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _PlanRow(plan: plans[i]),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // ---- تعديل البيانات (بعد الباقات)
          const LiveAccountActions(),
          // لوحة التحكم: تظهر فقط بعد دخول المالك أو المشرف بحسابه.
          ListenableBuilder(
            listenable: LiveController.instance,
            builder: (context, _) {
              final live = LiveController.instance;
              if (!live.isRegistered || !(live.user?.isAdmin ?? false)) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LiveSettingRow(
                  icon: Icons.admin_panel_settings_rounded,
                  tone: GlyphTone.gold,
                  title: 'لوحة التحكم',
                  sub: 'للمالك والمشرفين فقط',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const LiveAdminScreen()),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          // ---- تسجيل الخروج أسفل الصفحة
          const LiveAccountActions(logoutOnly: true),
          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                Text('© 2026 Pentara AI · جميع الحقوق محفوظة',
                    style: AppTypography.caption.copyWith(color: c.inkMuted)),
                const SizedBox(height: 2),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text('الإصدار 1.0',
                      style: latinFigures(AppTypography.caption).copyWith(color: c.inkMuted)),
                ),
              ],
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

    return ShareableCard(
      shareText: 'انضم إلى بنتارا: مجلس من أقوى نماذج الذكاء الاصطناعي يحوّل فكرتك '
          'إلى مشروع متكامل. حمّل التطبيق من رابطي:\n$url',
      fileName: 'pentara-$userId.png',
      builder: (context, shareButton) => _card(d, url, shareButton),
    );
  }

  Widget _card(PentaraColors d, String url, Widget shareButton) {
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
                Row(
                  children: [
                    Expanded(
                      child: Text(name, style: AppTypography.title.copyWith(color: d.ink)),
                    ),
                    shareButton,
                  ],
                ),
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
                  // اتجاه ثابت من اليسار وهامش أبيض (منطقة هادئة) حتى تقرأه كل الكاميرات.
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: QrImageView(
                      data: url,
                      size: 112,
                      padding: const EdgeInsets.all(6),
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      backgroundColor: const Color(0xFFFFFFFF),
                    ),
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

/// الباقات الافتراضية إذا لم يصل رد السيرفر.
const _fallbackPlans = [
  LivePlan(id: 'regular', name: 'العادية', priceUsd: 30, perks: [
    'حتى 20 مشروعاً شهرياً',
    'نصوص وتحليل وخطط عمل وبحوث',
    'تطبيقات الويب وفلاتر غير متاحة (تستهلك الرصيد)',
  ]),
  LivePlan(id: 'max', name: 'ماكس', priceUsd: 80, perks: [
    'بحوث وتحاليل وخطط عمل',
    'تطبيق فلاتر واحد أو 3 تطبيقات ويب شهرياً',
  ]),
  LivePlan(id: 'top', name: 'العليا', priceUsd: 200, featured: true, perks: [
    '3 تطبيقات فلاتر، أو تطبيق فلاتر + 3 إلى 6 تطبيقات ويب',
    '5 إلى 10 مواقع، مع التحليل وخطط العمل',
    'الرصيد المتبقي آخر الشهر يصلك كود هدية',
  ]),
];

/// صف باقة مدمج: الاسم والسعر بخط عادي، وما تشمله بخط صغير داخل نفس البطاقة.
class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.plan});

  final LivePlan plan;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final featured = plan.featured;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: featured ? c.goldLine : c.border),
        boxShadow: featured ? AppColors.goldShadow : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Glyph(featured ? Icons.workspace_premium_rounded : Icons.layers_rounded,
              tone: featured ? GlyphTone.gold : GlyphTone.emerald, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(plan.name, style: AppTypography.bodyStrong.copyWith(color: c.ink, fontSize: 15)),
                    ),
                    if (featured) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                        decoration: ShapeDecoration(
                          color: c.surfaceSoft,
                          shape: StadiumBorder(side: BorderSide(color: c.goldLine)),
                        ),
                        child: Text('الأكثر تميزاً', style: AppTypography.caption.copyWith(color: c.goldText, fontSize: 11)),
                      ),
                    ],
                  ],
                ),
                for (final p in plan.perks)
                  Text('• $p',
                      style: AppTypography.caption.copyWith(color: c.inkMuted, fontSize: 11.5, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              plan.priceLabel,
              style: latinFigures(AppTypography.label).copyWith(color: featured ? c.goldText : c.ink, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

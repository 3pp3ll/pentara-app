import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/gold_button.dart';
import '../widgets/member_avatar.dart';
import '../widgets/pentara_logo.dart';
import '../widgets/project_card.dart';

/// الرئيسية. لا تقرأ AppState: الغلاف يملك الاختيار وتبديل التبويب
/// والتنبيهات، فلا توقظها نبضات المحاكاة.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onNewProject,
    required this.onOpenProject,
    required this.onNotifications,
  });

  /// «مشروع جديد»: يفتح السيناريو التجريبي المُعدّ مسبقاً.
  final VoidCallback onNewProject;

  /// يستقبل معرّف المشروع.
  final ValueChanged<String> onOpenProject;

  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final recent = <Project>[];
    for (final id in MockData.recentProjectIds) {
      final p = MockData.projectById(id);
      if (p != null) recent.add(p);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- الرأس: الشعار وزر الإشعارات
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const PentaraLogo(markSize: 40, showSubtitle: false),
              const Spacer(),
              GoldButton.disc(
                label: 'الإشعارات',
                filled: true,
                onTap: onNotifications,
                icon: const _BellIcon(color: AppColors.onGold),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ---- التحية والتاريخ (ثابتان)
          Text(
            MockData.homeGreeting,
            style: AppTypography.displayL.copyWith(color: c.ink),
          ),
          const SizedBox(height: 4),
          Text(
            MockData.homeDateLabel,
            style: AppTypography.label.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: 24),

          // ---- الزر الكبير
          SizedBox(
            width: double.infinity,
            child: GoldButton.primary(
              label: 'مشروع جديد',
              expand: true,
              onTap: onNewProject,
              icon: const _PlusIcon(color: AppColors.onGold),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'المجلس يحوّل فكرتك إلى مشروع متكامل، لا مجرد دردشة',
            style: AppTypography.body.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: 12),
          const _LastSessionBadge(),
          const SizedBox(height: 24),

          // ---- أعضاء الطاولة
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final m in MockData.members)
                  SizedBox(
                    width: 84,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MemberAvatar(member: m, size: 64),
                        const SizedBox(height: 4),
                        ExcludeSemantics(
                          child: Text(
                            m.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: AppTypography.caption
                                .copyWith(color: c.inkMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ---- آخر المشاريع (ثلاثة معرّفات ثابتة، لا take(3))
          Text(
            'آخر المشاريع',
            style: AppTypography.title.copyWith(color: c.ink),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < recent.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            ProjectCard(
              project: recent[i],
              showDetails: false,
              onTap: () => onOpenProject(recent[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

/// شارة «آخر جلسة: $0.42»: نصّان منفصلان حتى لا تبعثر خوارزمية الاتجاه
/// الثنائي علامة $. الرقم داخل LTR بخط Alexandria متساوي العرض.
/// ثابت عرض مستقل، وليس تكلفة بطاقة.
class _LastSessionBadge extends StatelessWidget {
  const _LastSessionBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: c.surface,
        shape: StadiumBorder(side: BorderSide(color: c.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'آخر جلسة:',
              style: AppTypography.caption.copyWith(color: c.inkMuted),
            ),
            const SizedBox(width: 6),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                formatUsd(MockData.lastSessionCostCents),
                style:
                    latinFigures(AppTypography.caption).copyWith(color: c.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// رموز مرسومة بـ CustomPainter (تعبئة على شبكة 24×24، بلا Icons)
// ---------------------------------------------------------------------------

class _BellIcon extends StatelessWidget {
  const _BellIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _BellPainter(color)),
    );
  }
}

class _BellPainter extends CustomPainter {
  const _BellPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // جسم الجرس.
    final body = Path()
      ..moveTo(4.5, 17)
      ..cubicTo(6.3, 15.4, 7, 13.8, 7, 10.5)
      ..cubicTo(7, 7.5, 9.2, 5.6, 12, 5.6)
      ..cubicTo(14.8, 5.6, 17, 7.5, 17, 10.5)
      ..cubicTo(17, 13.8, 17.7, 15.4, 19.5, 17)
      ..close();
    canvas.drawPath(body, fill);

    // المقبض العلوي.
    canvas.drawCircle(const Offset(12, 4.2), 1.6, fill);

    // اللسان: نصف قرص سفلي.
    final clapper = Path()
      ..moveTo(9.7, 18.6)
      ..arcToPoint(
        const Offset(14.3, 18.6),
        radius: const Radius.circular(2.3),
        clockwise: false,
      )
      ..close();
    canvas.drawPath(clapper, fill);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BellPainter old) => old.color != color;
}

class _PlusIcon extends StatelessWidget {
  const _PlusIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CustomPaint(painter: _PlusPainter(color)),
      ),
    );
  }
}

class _PlusPainter extends CustomPainter {
  const _PlusPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawRRect(
      RRect.fromLTRBR(10.5, 4, 13.5, 20, const Radius.circular(1.5)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(4, 10.5, 20, 13.5, const Radius.circular(1.5)),
      fill,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlusPainter old) => old.color != color;
}

// ignore_for_file: deprecated_member_use
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/project_card.dart' show latinFigures;

/// لوحة التحكم: للمالك فقط.
///
/// فحص المالك هنا حجب واجهة لنموذج محلي، لا تفويضاً أمنياً إنتاجياً.
/// كل القيم تجريبية وتبقى في الذاكرة خلال جلسة التشغيل فقط.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final app = AppStateScope.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: _Header(pointRight: rtl),
            ),
            Expanded(
              child: app.isOwner ? _Body(app: app) : const _NotOwner(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// الرأس
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.pointRight});

  final bool pointRight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        _BackButton(pointRight: pointRight),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'لوحة التحكم',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.title.copyWith(color: c.ink),
          ),
        ),
        const SizedBox(width: 8),
        DecoratedBox(
          decoration: ShapeDecoration(
            color: c.surfaceSoft,
            shape: StadiumBorder(side: BorderSide(color: c.goldLine)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            child: Text(
              'للمالك فقط',
              style: AppTypography.caption.copyWith(color: c.goldText),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.pointRight});

  final bool pointRight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final overlay = c.goldLine.withAlpha(31);
    return Tooltip(
      message: 'رجوع',
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: 'رجوع',
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
              onTap: () => Navigator.of(context).maybePop(),
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
                    painter: _ArrowPainter(
                      color: c.goldText,
                      pointRight: pointRight,
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

/// سهم الرجوع: يشير لليمين في RTL ولليسار في LTR.
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.color, required this.pointRight});

  final Color color;
  final bool pointRight;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final path = Path();
    if (pointRight) {
      path
        ..moveTo(4, 12)
        ..lineTo(20, 12)
        ..moveTo(14, 6)
        ..lineTo(20, 12)
        ..lineTo(14, 18);
    } else {
      path
        ..moveTo(20, 12)
        ..lineTo(4, 12)
        ..moveTo(10, 6)
        ..lineTo(4, 12)
        ..lineTo(10, 18);
    }
    canvas.drawPath(path, p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter old) =>
      old.color != color || old.pointRight != pointRight;
}

class _NotOwner extends StatelessWidget {
  const _NotOwner();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'هذه اللوحة للمالك فقط.',
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: c.inkMuted),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// الجسم
// ---------------------------------------------------------------------------

class _Body extends StatelessWidget {
  const _Body({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlanLimitsSection(app: app),
          const SizedBox(height: 16),
          _LayoutSection(app: app),
          const SizedBox(height: 16),
          _NameSection(app: app),
          const SizedBox(height: 16),
          _UsersSection(app: app),
          const SizedBox(height: 16),
          const _ProvidersSection(),
        ],
      ),
    );
  }
}

/// بطاقة قسم: surface بحد border بلا ظل.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.bodyStrong.copyWith(color: c.ink)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text(
      text,
      style: AppTypography.caption.copyWith(color: c.inkMuted),
    );
  }
}

// ---------------------------------------------------------------------------
// حدود الباقات
// ---------------------------------------------------------------------------

class _PlanLimitsSection extends StatelessWidget {
  const _PlanLimitsSection({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final plans = MockData.plans;
    final limits = app.planLimits;

    final children = <Widget>[
      const _Note(
        'إعدادات تجريبية محفوظة خلال جلسة التشغيل فقط؛ لا تغيّر رصيد الحساب '
        'أو نصوص الباقات حالياً.',
      ),
      const SizedBox(height: 4),
      // قرار تصميم معلن: المنزلقان بالاتجاه اللاتيني لتطابق الأرقام الغربية.
      const _Note('تزداد قيم المنزلقات نحو اليمين.'),
      const SizedBox(height: 12),
    ];

    var shown = 0;
    for (final plan in plans) {
      final l = limits[plan.id];
      if (l == null) continue;
      if (shown > 0) {
        children.add(Divider(color: c.border, height: 28, thickness: 1));
      }
      shown++;
      children.add(_PlanLimitsBlock(app: app, plan: plan, limits: l));
    }

    if (shown == 0) {
      children.add(Text(
        'لا توجد باقات متاحة',
        style: AppTypography.body.copyWith(color: c.inkMuted),
      ));
    }

    return _Section(title: 'حدود الباقات', children: children);
  }
}

class _PlanLimitsBlock extends StatelessWidget {
  const _PlanLimitsBlock({
    required this.app,
    required this.plan,
    required this.limits,
  });

  final AppState app;
  final Plan plan;
  final PlanLimits limits;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final floorUsd = app.creditFloorUsd(plan.id); // null: يتجاوز المدى
    final creditValue = limits.creditLimitUsd
        .clamp(PlanLimits.minCreditUsd, PlanLimits.maxCreditUsd)
        .toDouble();
    final projectsValue = limits.monthlyProjects
        .clamp(PlanLimits.minProjects, PlanLimits.maxProjects)
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(plan.name, style: AppTypography.bodyStrong.copyWith(color: c.goldText)),
        const SizedBox(height: 8),
        _LimitSlider(
          label: 'مشاريع شهرياً',
          valueText: '${limits.monthlyProjects}',
          value: projectsValue,
          min: PlanLimits.minProjects.toDouble(),
          max: PlanLimits.maxProjects.toDouble(),
          divisions: PlanLimits.projectDivisions,
          minText: '${PlanLimits.minProjects}',
          maxText: '${PlanLimits.maxProjects}',
          onChanged: (v) => app.setPlanMonthlyProjects(plan.id, v),
        ),
        const SizedBox(height: 8),
        _LimitSlider(
          label: 'حد الرصيد',
          valueText: limits.creditLimitLabel,
          value: creditValue,
          min: PlanLimits.minCreditUsd.toDouble(),
          max: PlanLimits.maxCreditUsd.toDouble(),
          divisions: PlanLimits.creditDivisions,
          minText: formatUsd(PlanLimits.minCreditUsd * 100),
          maxText: formatUsd(PlanLimits.maxCreditUsd * 100),
          onChanged: floorUsd == null
              ? null
              : (v) => app.setPlanCreditLimitUsd(plan.id, v),
        ),
        if (floorUsd == null)
          const _Note(
            'الاستهلاك المسجّل يتجاوز \$200؛ تعديل الرصيد معطّل لهذه الباقة.',
          )
        else if (floorUsd > PlanLimits.minCreditUsd)
          _Note(
            'الحد الأدنى لهذه الباقة ${formatUsd(floorUsd * 100)} '
            'بسبب الاستهلاك المسجّل.',
          ),
      ],
    );
  }
}

class _LimitSlider extends StatelessWidget {
  const _LimitSlider({
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.minText,
    required this.maxText,
    required this.onChanged,
  });

  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String minText;
  final String maxText;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = SliderTheme.of(context).copyWith(
      trackHeight: 6,
      activeTrackColor: AppColors.gold500,
      inactiveTrackColor: c.track,
      thumbColor: c.goldLine,
      overlayColor: c.goldLine.withAlpha(31),
      activeTickMarkColor: Colors.transparent,
      inactiveTickMarkColor: Colors.transparent,
      disabledActiveTrackColor: c.border,
      disabledInactiveTrackColor: c.track,
      disabledThumbColor: c.inkMuted,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.label.copyWith(color: c.inkMuted),
              ),
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                valueText,
                style: latinFigures(AppTypography.bodyStrong)
                    .copyWith(color: c.ink),
              ),
            ),
          ],
        ),
        // الشريط وعلامتا الطرفين معاً بالاتجاه اللاتيني: الأدنى يساراً.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              SliderTheme(
                data: theme,
                child: Slider(
                  value: value.clamp(min, max).toDouble(),
                  min: min,
                  max: max,
                  divisions: divisions,
                  semanticFormatterCallback: (_) => valueText,
                  onChanged: onChanged,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      minText,
                      style: latinFigures(AppTypography.caption)
                          .copyWith(color: c.inkMuted),
                    ),
                    Text(
                      maxText,
                      style: latinFigures(AppTypography.caption)
                          .copyWith(color: c.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// بطاقة اختيار عامة
// ---------------------------------------------------------------------------

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.onTap,
    required this.semanticsLabel,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final String semanticsLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: selected ? c.surfaceSoft : c.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? c.goldLine : c.border,
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ترتيب أعضاء الطاولة
// ---------------------------------------------------------------------------

class _LayoutSection extends StatelessWidget {
  const _LayoutSection({required this.app});

  final AppState app;

  static const _options = <(MembersLayout, String)>[
    (MembersLayout.row, 'صف واحد'),
    (MembersLayout.grid4, '٤ وتحتها الباقي'),
    (MembersLayout.table, 'شكل الطاولة'),
  ];

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return _Section(
      title: 'ترتيب أعضاء الطاولة في الرئيسية',
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final vertical = constraints.maxWidth < 340 || scale > 1.2;
            final cards = <Widget>[
              for (final o in _options)
                _LayoutCard(
                  layout: o.$1,
                  label: o.$2,
                  selected: app.membersLayout == o.$1,
                  wide: vertical,
                  onTap: () => app.membersLayout = o.$1,
                ),
            ];
            if (vertical) {
              return Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    cards[i],
                  ],
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: cards[i]),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LayoutCard extends StatelessWidget {
  const _LayoutCard({
    required this.layout,
    required this.label,
    required this.selected,
    required this.wide,
    required this.onTap,
  });

  final MembersLayout layout;
  final String label;
  final bool selected;
  final bool wide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final preview = CustomPaint(
      painter: _LayoutPreviewPainter(
        layout: layout,
        dot: c.inkMuted,
        chair: AppColors.gold500,
        ring: c.border,
      ),
    );
    final text = Text(
      label,
      textAlign: wide ? TextAlign.start : TextAlign.center,
      style: AppTypography.caption.copyWith(
        color: selected ? c.goldText : c.ink,
      ),
    );

    return _ChoiceCard(
      selected: selected,
      onTap: onTap,
      semanticsLabel: 'ترتيب الأعضاء: $label',
      child: wide
          ? Row(
              children: [
                SizedBox(width: 96, height: 56, child: preview),
                const SizedBox(width: 12),
                Expanded(child: text),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 56, width: double.infinity, child: preview),
                const SizedBox(height: 8),
                text,
              ],
            ),
    );
  }
}

/// معاينة مصغّرة: ست نقاط، الرئيس بالذهبي (يمين الصف / أعلى الطاولة).
class _LayoutPreviewPainter extends CustomPainter {
  const _LayoutPreviewPainter({
    required this.layout,
    required this.dot,
    required this.chair,
    required this.ring,
  });

  final MembersLayout layout;
  final Color dot;
  final Color chair;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 4.5;
    final paint = Paint()..isAntiAlias = true;

    void drawDot(Offset o, bool isChair) {
      paint.color = isChair ? chair : dot;
      canvas.drawCircle(o, r, paint);
    }

    switch (layout) {
      case MembersLayout.row:
        final slot = size.width / 6;
        for (var i = 0; i < 6; i++) {
          drawDot(Offset(size.width - slot * (i + 0.5), size.height / 2), i == 0);
        }
      case MembersLayout.grid4:
        final slot = size.width / 4;
        for (var i = 0; i < 4; i++) {
          drawDot(Offset(size.width - slot * (i + 0.5), size.height * 0.3), i == 0);
        }
        drawDot(Offset(size.width / 2 + slot / 2, size.height * 0.72), false);
        drawDot(Offset(size.width / 2 - slot / 2, size.height * 0.72), false);
      case MembersLayout.table:
        final center = Offset(size.width / 2, size.height / 2);
        final radius = math.min(size.width, size.height) / 2 - r - 2;
        final stroke = Paint()
          ..color = ring
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..isAntiAlias = true;
        canvas.drawCircle(center, radius, stroke);
        for (var i = 0; i < 6; i++) {
          final a = -math.pi / 2 + i * math.pi / 3;
          drawDot(
            Offset(center.dx + radius * math.cos(a),
                center.dy + radius * math.sin(a)),
            i == 0,
          );
        }
    }
  }

  @override
  bool shouldRepaint(covariant _LayoutPreviewPainter old) =>
      old.layout != layout ||
      old.dot != dot ||
      old.chair != chair ||
      old.ring != ring;
}

// ---------------------------------------------------------------------------
// اسم التطبيق
// ---------------------------------------------------------------------------

class _NameSection extends StatelessWidget {
  const _NameSection({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const arabic = 'بنتارا';
    const latin = 'Pentara AI';

    Widget card(String name, bool isLatin) {
      final selected = app.appName == name;
      final style = isLatin
          ? latinFigures(AppTypography.bodyStrong)
          : AppTypography.bodyStrong;
      Widget text = Text(
        name,
        textAlign: TextAlign.center,
        style: style.copyWith(color: selected ? c.goldText : c.ink),
      );
      if (isLatin) {
        text = Directionality(textDirection: TextDirection.ltr, child: text);
      }
      return _ChoiceCard(
        selected: selected,
        onTap: () => app.appName = name,
        semanticsLabel: 'اسم التطبيق: $name',
        child: Center(child: text),
      );
    }

    return _Section(
      title: 'اسم التطبيق',
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: card(arabic, false)),
              const SizedBox(width: 8),
              Expanded(child: card(latin, true)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const _Note('يُحفظ في الحالة فقط؛ لا يغيّر الشعار في الرئيسية حالياً.'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// المستخدمون
// ---------------------------------------------------------------------------

class _UsersSection extends StatelessWidget {
  const _UsersSection({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final users = app.users;
    return _Section(
      title: 'المستخدمون',
      children: [
        for (var i = 0; i < users.length; i++) ...[
          if (i > 0) Divider(color: c.border, height: 20, thickness: 1),
          _UserRow(app: app, user: users[i]),
        ],
      ],
    );
  }
}

String _planName(String planId) {
  for (final p in MockData.plans) {
    if (p.id == planId) return p.name;
  }
  return 'باقة غير معروفة';
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.app, required this.user});

  final AppState app;
  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final owner = user.id == ownerUserId;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: AppTypography.bodyStrong.copyWith(
                    color: user.isActive ? c.ink : c.inkMuted,
                  ),
                ),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    'ID ${user.id}',
                    style: latinFigures(AppTypography.caption)
                        .copyWith(color: c.inkMuted),
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 12,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _planName(user.planId),
                      style: AppTypography.caption.copyWith(color: c.goldText),
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        user.consumedLabel,
                        style: latinFigures(AppTypography.caption)
                            .copyWith(color: c.ink),
                      ),
                    ),
                    if (owner)
                      Text(
                        'المالك: لا يمكن إيقافه',
                        style:
                            AppTypography.caption.copyWith(color: c.inkMuted),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: 'تفعيل ${user.name}',
            child: Switch(
              value: user.isActive,
              // المالك: بلا معالج. والرفض الفعلي أيضاً داخل setUserActive.
              onChanged:
                  owner ? null : (v) => app.setUserActive(user.id, v),
              thumbColor: MaterialStateProperty.resolveWith((states) {
                return states.contains(MaterialState.selected)
                    ? c.goldLine
                    : c.inkMuted;
              }),
              trackColor: MaterialStateProperty.resolveWith((states) {
                return states.contains(MaterialState.selected)
                    ? c.surfaceSoft
                    : c.track;
              }),
              trackOutlineColor: MaterialStateProperty.resolveWith((states) {
                return states.contains(MaterialState.selected)
                    ? c.goldLine
                    : c.border;
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// مفاتيح النماذج: عرض فقط، بلا حقول ولا أسرار
// ---------------------------------------------------------------------------

class _Provider {
  const _Provider(this.name, this.connected);

  final String name;
  final bool connected;
}

class _ProvidersSection extends StatelessWidget {
  const _ProvidersSection();

  static const _providers = <_Provider>[
    _Provider('المزوّد الأول', true),
    _Provider('المزوّد الثاني', false),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _Section(
      title: 'مفاتيح النماذج',
      children: [
        for (var i = 0; i < _providers.length; i++) ...[
          if (i > 0) Divider(color: c.border, height: 20, thickness: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _providers[i].name,
                    style: AppTypography.bodyStrong.copyWith(color: c.ink),
                  ),
                ),
                _StatePill(connected: _providers[i].connected),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        const _Note(
          'عرض تجريبي: الحالتان للمعاينة فقط؛ لا مفاتيح مخزّنة ولا اتصال فعلي.',
        ),
      ],
    );
  }
}

/// «متصل» بنغمة ok و«غير مضبوط» بنغمة neutral، من سداسيات جدول المرجع.
/// الحالة تُفهم من النص لا من اللون وحده.
class _StatePill extends StatelessWidget {
  const _StatePill({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final Color ink;
    final Color bg;
    if (connected) {
      ink = dark ? const Color(0xFF7FDDB3) : const Color(0xFF1F6B4A);
      bg = dark ? const Color(0xFF173A2C) : const Color(0xFFE2F2EA);
    } else {
      ink = dark ? const Color(0xFFC2C7D4) : const Color(0xFF4E556B);
      bg = dark ? const Color(0xFF262D45) : const Color(0xFFECEAE3);
    }
    return DecoratedBox(
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Text(
          connected ? 'متصل' : 'غير مضبوط',
          style: AppTypography.caption.copyWith(color: ink),
        ),
      ),
    );
  }
}

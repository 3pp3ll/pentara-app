import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/gold_button.dart';
import '../widgets/member_icons.dart';
import '../widgets/pentara_logo.dart';
import '../widgets/project_card.dart';

const List<String> _weekdays = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

const List<String> _months = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// التحية حسب الساعة: قبل 12 «صباح الخير»، ومن 12 «مساء الخير».
String greetingFor(DateTime d, String name) =>
    '${d.hour < 12 ? 'صباح' : 'مساء'} الخير، $name';

/// تاريخ اليوم بالعربي بأرقام عربية (سرد). DateTime.weekday يبدأ من 1 للاثنين.
String arabicDateLabel(DateTime d) => toArabicDigits(
      '${_weekdays[d.weekday - 1]}، ${d.day} ${_months[d.month - 1]} ${d.year}',
    );

/// الرئيسية. التحية والتاريخ من ساعة الجوال، وتُحدَّثان عند العودة من
/// الخلفية وبمؤقّت واحد غير متكرر عند الحد التالي (الظهر أو منتصف الليل).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onNewProject,
    required this.onOpenProject,
    required this.onNotifications,
    this.clock,
  });

  final VoidCallback onNewProject;
  final ValueChanged<String> onOpenProject;
  final VoidCallback onNotifications;
  final DateTime Function()? clock;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late String _greeting;
  late String _date;
  Timer? _timer;

  DateTime _read() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final now = _read();
    _greeting = greetingFor(now, MockData.account.displayName);
    _date = arabicDateLabel(now);
    _schedule(now);
  }

  void _sync() {
    if (!mounted) return;
    final now = _read();
    final g = greetingFor(now, MockData.account.displayName);
    final d = arabicDateLabel(now);
    if (g != _greeting || d != _date) {
      setState(() {
        _greeting = g;
        _date = d;
      });
    }
    _schedule(now);
  }

  void _schedule(DateTime now) {
    _timer?.cancel();
    final next = now.hour < 12
        ? DateTime(now.year, now.month, now.day, 12)
        : DateTime(now.year, now.month, now.day + 1);
    final diff = next.difference(now);
    final delay = diff.isNegative
        ? const Duration(seconds: 1)
        : diff + const Duration(seconds: 1);
    _timer = Timer(delay, _sync);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sync();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final recent = <Project>[];
    for (final id in MockData.recentProjectIds) {
      final p = MockData.projectById(id);
      if (p != null) recent.add(p);
    }

    // الحشو العلوي 16 تحت SafeArea التي يوفّرها الغلاف (بلا SafeArea ثانية).
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const PentaraLogo(markSize: 40, showSubtitle: false),
              const Spacer(),
              GoldButton.disc(
                label: 'الإشعارات',
                filled: true,
                onTap: widget.onNotifications,
                icon: const _BellIcon(color: AppColors.onGold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            _greeting,
            style: AppTypography.displayL.copyWith(color: c.ink),
          ),
          const SizedBox(height: 4),
          Text(
            _date,
            style: AppTypography.label.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: 24),

          // بعرض الشاشة كاملاً ناقص حاشية 24 (حشو الشاشة نفسه).
          SizedBox(
            width: double.infinity,
            child: GoldButton.primary(
              label: 'مشروع جديد',
              expand: true,
              onTap: widget.onNewProject,
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

          // يتبع membersLayout. هذا الويدجت وحده يعتمد على AppState، فتبقى
          // التحية وآخر المشاريع خارج إعادة البناء عند نبضات المحاكاة.
          const _MembersSection(),
          const SizedBox(height: 24),

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
              onTap: () => widget.onOpenProject(recent[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// أعضاء الطاولة
// ---------------------------------------------------------------------------

/// يعرض الأعضاء حسب membersLayout. الأقراص بعتامة كاملة هنا: صف عرض بلا
/// متحدث حالي، وشفافية 0.85 لغير المتحدث تخص الطاولة فقط.
/// القائمة بلا عكس: RTL يضع الرئيس يميناً والمدقق يساراً.
class _MembersSection extends StatelessWidget {
  const _MembersSection();

  @override
  Widget build(BuildContext context) {
    final layout = AppStateScope.of(context).membersLayout;
    final members = MockData.members;

    switch (layout) {
      case MembersLayout.row:
        return _RowLayout(members: members);
      case MembersLayout.grid4:
        return _Grid4Layout(members: members);
      case MembersLayout.table:
        return _TableLayout(members: members);
    }
  }
}

/// قرص 44 مرئي فعلاً (MemberAvatar(size: 44) يرسم نحو 29)، ولقب 12 بلونه.
class _MemberCell extends StatelessWidget {
  const _MemberCell({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = member.id == MemberId.chair ? 'الرئيس' : member.title;
    return Semantics(
      label: '${member.title}، ${member.role}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: member.palette.disc,
            ),
            child: MemberIcon(
              symbol: member.symbol,
              size: 22,
              color: const Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: c.memberName(member.id)),
          ),
        ],
      ),
    );
  }
}

/// صف واحد: ستة Expanded. حد المحتوى 6×44 = 264 (يلزم شاشة بعرض 312 مع
/// الحاشية). تحت ذلك يُمرَّر أفقياً بعرض أدنى 264 دون تصغير الأقراص.
class _RowLayout extends StatelessWidget {
  const _RowLayout({required this.members});

  final List<Member> members;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final m in members)
              Expanded(child: Center(child: _MemberCell(member: m))),
          ],
        );
        if (box.maxWidth >= 264) return row;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: 264, child: row),
        );
      },
    );
  }
}

/// أربعة في الصف الأول، واثنان متوسَّطان تحتها بفجوة 8.
class _Grid4Layout extends StatelessWidget {
  const _Grid4Layout({required this.members});

  final List<Member> members;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 8.0;
        final cellW = ((box.maxWidth - 3 * gap) / 4).clamp(44.0, 200.0);

        Widget cell(Member m) =>
            SizedBox(width: cellW, child: Center(child: _MemberCell(member: m)));

        final first = members.take(4).toList();
        final second = members.skip(4).toList();

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < first.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  cell(first[i]),
                ],
              ],
            ),
            const SizedBox(height: gap),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < second.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  cell(second[i]),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

/// دائرة مصغّرة داخل مربع 200×200 (لا يتجاوز قيد الأب): الرئيس أعلاها ثم مع
/// عقارب الساعة بالهوية الثابتة. الألقاب مقيّدة داخل المربع مع ellipsis؛
/// عند تكبير الخط قد يُقصّ اللقب ولا يُكبَّر المربع.
class _TableLayout extends StatelessWidget {
  const _TableLayout({required this.members});

  final List<Member> members;

  static const List<MemberId> _order = [
    MemberId.chair,
    MemberId.engineer,
    MemberId.practical,
    MemberId.analyst,
    MemberId.challenger,
    MemberId.auditor,
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.min(box.maxWidth, 200.0);
        final cx = side / 2;
        final cy = side / 2;
        const cellW = 56.0;
        const cellH = 64.0;
        const r = 58.0;

        final children = <Widget>[
          Positioned(
            left: cx - r,
            top: cy - r,
            width: r * 2,
            height: r * 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surfaceSoft,
                border: Border.all(color: c.border, width: 1),
              ),
            ),
          ),
        ];

        for (var i = 0; i < _order.length; i++) {
          Member? m;
          for (final x in members) {
            if (x.id == _order[i]) m = x;
          }
          if (m == null) continue;
          final theta = -math.pi / 2 + i * math.pi / 3;
          final left = (cx + r * math.cos(theta) - cellW / 2)
              .clamp(0.0, math.max(0.0, side - cellW))
              .toDouble();
          final top = (cy + r * math.sin(theta) - 22)
              .clamp(0.0, math.max(0.0, side - cellH))
              .toDouble();
          children.add(
            Positioned(
              left: left,
              top: top,
              width: cellW,
              child: _MemberCell(member: m),
            ),
          );
        }

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(clipBehavior: Clip.none, children: children),
          ),
        );
      },
    );
  }
}

/// شارة «آخر جلسة: $0.42»: نصّان منفصلان حتى لا تبعثر خوارزمية الاتجاه
/// الثنائي علامة $. ثابت عرض مستقل، وليس تكلفة بطاقة.
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

    final body = Path()
      ..moveTo(4.5, 17)
      ..cubicTo(6.3, 15.4, 7, 13.8, 7, 10.5)
      ..cubicTo(7, 7.5, 9.2, 5.6, 12, 5.6)
      ..cubicTo(14.8, 5.6, 17, 7.5, 17, 10.5)
      ..cubicTo(17, 13.8, 17.7, 15.4, 19.5, 17)
      ..close();
    canvas.drawPath(body, fill);
    canvas.drawCircle(const Offset(12, 4.2), 1.6, fill);

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

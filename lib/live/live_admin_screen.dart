import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/gold_button.dart';
import '../widgets/project_card.dart' show latinFigures;
import 'live_api.dart';
import 'live_session.dart';

const _danger = Color(0xFFA8322E);
const _ok = Color(0xFF1F6B4A);

/// لوحة التحكم: شاشة رئيسية فخمة من أيقونات كبيرة، كل أيقونة تفتح قسمها.
/// للمالك ومن يمنحه صلاحية مشرف.
class LiveAdminScreen extends StatefulWidget {
  const LiveAdminScreen({super.key});

  @override
  State<LiveAdminScreen> createState() => _LiveAdminScreenState();
}

const _tealGradient = LinearGradient(
  begin: AppColors.disc145Begin,
  end: AppColors.disc145End,
  colors: [Color(0xFF2E9C8A), Color(0xFF0B5E54)],
);

class _Section {
  const _Section(this.icon, this.title, this.sub, this.page, {this.soon = false});
  final IconData icon;
  final String title;
  final String sub;
  final Widget Function()? page;
  final bool soon;
}

class _LiveAdminScreenState extends State<LiveAdminScreen> {
  late Future<Map<String, dynamic>> _dash = _load();

  LiveController get live => LiveController.instance;

  Future<Map<String, dynamic>> _load() async {
    final r = await live.adminGet('dashboard');
    return (r['dashboard'] as Map?)?.cast<String, dynamic>() ?? const {};
  }

  void _open(_Section s, int i) {
    if (s.soon || s.page == null) {
      _toast(context, '${s.title}: قريباً');
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
          builder: (_) => _AdminPage(title: s.title, icon: s.icon, alt: i.isOdd, child: s.page!()),
        ))
        .then((_) {
      if (mounted) setState(() => _dash = _load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final u = live.user;
    final isOwner = u?.isOwner ?? false;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _dash,
          builder: (context, snap) {
            final d = snap.data ?? const <String, dynamic>{};
            int n(Object? v) => (v as num?)?.toInt() ?? 0;
            final sessions = (d['sessions'] as Map?)?.cast<String, dynamic>() ?? const {};
            final sales = (d['sales'] as Map?)?.cast<String, dynamic>() ?? const {};
            final has = snap.hasData;
            String cnt(Object? v, String unit) => has ? '${n(v)} $unit' : '…';
            final sections = <_Section>[
              _Section(Icons.insights_rounded, 'الإحصائيات', 'رسوم وأرقام حية', () => const _Overview()),
              _Section(Icons.groups_rounded, 'المستخدمون', cnt(d['users'], 'حساب'), () => const _Users()),
              _Section(Icons.admin_panel_settings_rounded, 'الصلاحيات', cnt(d['admins'], 'مشرف'),
                  () => const _Users(filter: 'admins')),
              _Section(Icons.devices_rounded, 'الأجهزة', 'ربط الأجهزة وفكّها', () => const _Users(filter: 'multi')),
              _Section(Icons.confirmation_number_rounded, 'الأكواد', cnt(sales['count'], 'مفعّل'),
                  () => const _Codes()),
              _Section(Icons.tune_rounded, 'الإعدادات', 'نص الإحالة والخيارات', () => const _Settings()),
              _Section(Icons.history_rounded, 'السجل', 'كل حركة بوقتها', () => const _Log()),
              const _Section(Icons.workspace_premium_rounded, 'الباقات', 'حدود كل باقة', null, soon: true),
            ];
            return RefreshIndicator(
              color: c.goldLine,
              onRefresh: () async {
                setState(() => _dash = _load());
                await _dash.catchError((_) => const <String, dynamic>{});
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Row(
                    children: [
                      _squareBack(context),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('لوحة التحكم', style: AppTypography.title.copyWith(color: c.ink)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: AppColors.goldDiscGradient,
                        ),
                        child: Text(isOwner ? 'المالك' : 'مشرف',
                            style: AppTypography.caption.copyWith(color: AppColors.onGold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _hero(context, u?.name.trim() ?? ''),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _miniKpi(context, has ? '${n(d['users'])}' : '…', 'مستخدم')),
                      const SizedBox(width: 10),
                      Expanded(child: _miniKpi(context, has ? '${n(d['newThisWeek'])}' : '…', 'جديد هالأسبوع')),
                      const SizedBox(width: 10),
                      Expanded(child: _miniKpi(context, has ? '${n(sessions['sessions'])}' : '…', 'جلسة')),
                    ],
                  ),
                  if (snap.hasError) ...[
                    const SizedBox(height: 8),
                    Text(_err(snap.error!), style: AppTypography.caption.copyWith(color: _danger)),
                  ],
                  const SizedBox(height: 12),
                  _webPanel(context),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sections.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: wide ? 4 : 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 168,
                    ),
                    itemBuilder: (context, i) => _Tile(
                      section: sections[i],
                      index: i,
                      onTap: () => _open(sections[i], i),
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.logout_rounded, color: c.ink, size: 20),
                    label: Text('خروج من لوحة التحكم', style: AppTypography.bodyStrong.copyWith(color: c.ink)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: BorderSide(color: c.border),
                      backgroundColor: c.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// لوحة الموقع تفتح داخل التطبيق (متصفح مدمج) وتدخل تلقائياً بحسابك.
  Future<void> _openWeb() async {
    final uri = Uri.parse(live.webAdminUrl);
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {}
    if (!ok) {
      try {
        ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    if (!ok && mounted) _toast(context, 'تعذّر فتح لوحة الموقع');
  }

  Widget _webPanel(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: c.goldLine.withAlpha(150)),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        onTap: _openWeb,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: _tealGradient),
                child: const Icon(Icons.language_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('لوحة التحكم على الموقع', style: AppTypography.bodyStrong.copyWith(color: c.ink)),
                    Text('تفتح هنا وتدخل بحسابك، وأي تعديل يُحفظ في الموقع',
                        style: AppTypography.caption.copyWith(color: c.inkMuted)),
                  ],
                ),
              ),
              Icon(Icons.open_in_new_rounded, color: c.goldText, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, String name) {
    final h = DateTime.now().hour;
    final greet = h < 12 ? 'صباح الخير' : 'مساء الخير';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: AppColors.disc145Begin,
          end: AppColors.disc145End,
          colors: [AppColors.goldLight, AppColors.goldDiscStart, AppColors.goldDeep],
        ),
        boxShadow: AppColors.goldShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(70),
              border: Border.all(color: Colors.white.withAlpha(140)),
            ),
            child: const Icon(Icons.shield_rounded, color: AppColors.onGold, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? greet : '$greet يا $name',
                    style: AppTypography.bodyStrong.copyWith(color: AppColors.onGold, fontSize: 17)),
                const SizedBox(height: 2),
                Text('كل أدوات بنتارا في مكان واحد',
                    style: AppTypography.label.copyWith(color: AppColors.onGold.withAlpha(190))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniKpi(BuildContext context, String v, String label) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.goldLine.withAlpha(120)),
      ),
      child: Column(
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(v, style: latinFigures(AppTypography.title).copyWith(color: c.goldText)),
          ),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(color: c.inkMuted)),
        ],
      ),
    );
  }
}

Widget _squareBack(BuildContext context) {
  final c = context.colors;
  return Material(
    color: c.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: c.border)),
    child: InkWell(
      customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onTap: () => Navigator.of(context).maybePop(),
      child: SizedBox(
        width: 42,
        height: 42,
        child: Icon(Icons.arrow_forward_rounded, color: c.ink, size: 20),
      ),
    ),
  );
}

/// أيقونة كبيرة: مربع متدرج (ذهبي أو زمردي بالتناوب) فيه الرمز، والعنوان والوصف تحته.
class _Tile extends StatelessWidget {
  const _Tile({required this.section, required this.index, required this.onTap});
  final _Section section;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = section;
    final tile = Material(
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: c.border)),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 18, 8, 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: index.isOdd ? _tealGradient : AppColors.goldDiscGradient,
                      boxShadow: [
                        BoxShadow(
                          color: (index.isOdd ? const Color(0xFF0B5E54) : AppColors.goldDeep).withAlpha(60),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(s.icon, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 10),
                  Text(s.title, style: AppTypography.bodyStrong.copyWith(color: c.ink)),
                  const SizedBox(height: 2),
                  Text(s.sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
            if (s.soon)
              PositionedDirectional(
                top: 10,
                start: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: c.goldLine),
                    color: c.surfaceSoft,
                  ),
                  child: Text('قريباً', style: AppTypography.caption.copyWith(color: c.goldText)),
                ),
              ),
          ],
        ),
      ),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index * 60),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0).toDouble() * (s.soon ? 0.55 : 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
        ),
      ),
      child: tile,
    );
  }
}

/// صفحة قسم: رأس بزر رجوع وأيقونة القسم، وتحته المحتوى.
class _AdminPage extends StatelessWidget {
  const _AdminPage({required this.title, required this.icon, required this.alt, required this.child});
  final String title;
  final IconData icon;
  final bool alt;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  _squareBack(context),
                  const SizedBox(width: 10),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: alt ? _tealGradient : AppColors.goldDiscGradient,
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(title, style: AppTypography.title.copyWith(color: c.ink))),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

// ---- أدوات مشتركة -------------------------------------------------------------

void _toast(BuildContext context, String m) {
  final c = context.colors;
  ScaffoldMessenger.maybeOf(context)
    ?..clearSnackBars()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      content: Text(m, style: AppTypography.label.copyWith(color: c.bg)),
    ));
}

String _err(Object e) => e is LiveException ? e.message : 'حدث خطأ';

Widget _card(BuildContext context, {required Widget child, EdgeInsets? padding}) {
  final c = context.colors;
  return Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: c.border),
    ),
    child: child,
  );
}

Widget _kpi(BuildContext context, String label, String value, IconData icon) {
  final c = context.colors;
  return _card(
    context,
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: c.goldText),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(color: c.inkMuted)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: latinFigures(AppTypography.metric).copyWith(color: c.ink)),
        ),
      ],
    ),
  );
}

InputDecoration _dec(BuildContext context, String hint) {
  final c = context.colors;
  return InputDecoration(
    hintText: hint,
    hintStyle: AppTypography.label.copyWith(color: c.inkMuted),
    filled: true,
    fillColor: c.bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
    enabledBorder:
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.goldLine, width: 1.5)),
  );
}

/// غلاف تحميل موحّد: يجلب البيانات ويعرض خطأ مع «إعادة المحاولة».
class _Loader extends StatefulWidget {
  const _Loader({super.key, required this.load, required this.builder});

  final Future<Map<String, dynamic>> Function() load;
  final Widget Function(BuildContext context, Map<String, dynamic> data, VoidCallback reload) builder;

  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _error = null);
    try {
      final d = await widget.load();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = _err(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: AppTypography.body.copyWith(color: _danger)),
              const SizedBox(height: 12),
              GoldButton.secondary(label: 'إعادة المحاولة', onTap: _reload),
            ],
          ),
        ),
      );
    }
    if (_data == null) return Center(child: CircularProgressIndicator(color: c.goldLine));
    return RefreshIndicator(
      color: c.goldLine,
      onRefresh: _reload,
      child: widget.builder(context, _data!, _reload),
    );
  }
}

// ---- نظرة عامة ----------------------------------------------------------------

class _Overview extends StatelessWidget {
  const _Overview();

  @override
  Widget build(BuildContext context) {
    return _Loader(
      load: () => LiveController.instance.adminGet('dashboard'),
      builder: (context, data, _) {
        final c = context.colors;
        final d = (data['dashboard'] as Map?)?.cast<String, dynamic>() ?? const {};
        final sessions = (d['sessions'] as Map?)?.cast<String, dynamic>() ?? const {};
        final sales = (d['sales'] as Map?)?.cast<String, dynamic>() ?? const {};
        final names = (d['planNames'] as Map?)?.cast<String, dynamic>() ?? const {};
        final byPlan = (d['byPlan'] as Map?)?.cast<String, dynamic>() ?? const {};
        final byOutput = (sessions['byOutput'] as Map?)?.cast<String, dynamic>() ?? const {};
        int n(Object? v) => (v as num?)?.toInt() ?? 0;
        final salesCredit = n(sales['creditMicros']);
        // الرصيد المفعّل = 70% من قيمة الاشتراك، فالقيمة التقديرية للمبيعات = الرصيد ÷ 0.7.
        final revenue = (salesCredit / 0.7).round();

        final planSlices = [
          for (final e in byPlan.entries) _Slice('${names[e.key] ?? e.key}', n(e.value)),
        ]..sort((a, b) => b.value.compareTo(a.value));

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            GridView.count(
              crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: [
                _kpi(context, 'المستخدمون', '${n(d['users'])}', Icons.groups_rounded),
                _kpi(context, 'المسجّلون', '${n(d['registered'])}', Icons.verified_user_rounded),
                _kpi(context, 'جدد هذا الأسبوع', '${n(d['newThisWeek'])}', Icons.trending_up_rounded),
                _kpi(context, 'الزوار', '${n(d['guests'])}', Icons.person_outline_rounded),
                _kpi(context, 'الجلسات', '${n(sessions['sessions'])}', Icons.forum_rounded),
                _kpi(context, 'تكلفة النماذج', formatMicros(n(sessions['costMicros'])), Icons.memory_rounded),
                _kpi(context, 'أكواد مفعّلة', '${n(sales['count'])}', Icons.confirmation_number_rounded),
                _kpi(context, 'مبيعات تقديرية', formatMicros(revenue), Icons.payments_rounded),
              ],
            ),
            const SizedBox(height: 16),
            _card(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('المستخدمون حسب الباقة', style: AppTypography.bodyStrong.copyWith(color: c.ink)),
                  const SizedBox(height: 12),
                  _Donut(slices: planSlices),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _card(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الجلسات حسب النوع', style: AppTypography.bodyStrong.copyWith(color: c.ink)),
                  const SizedBox(height: 12),
                  _Bars(items: [
                    for (final o in LiveOutput.values) _Slice(o.category, n(byOutput[o.name])),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _card(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الأرصدة', style: AppTypography.bodyStrong.copyWith(color: c.ink)),
                  const SizedBox(height: 8),
                  _line(context, 'رصيد متبقٍ عند المستخدمين', formatMicros(n(d['balanceMicros']))),
                  _line(context, 'مصروف المستخدمين على النماذج', formatMicros(n(d['spentMicros']))),
                  _line(context, 'رصيد الأكواد المفعّلة', formatMicros(salesCredit)),
                  _line(context, 'حسابات معطّلة', '${n(d['disabled'])}'),
                  _line(context, 'مشرفون', '${n(d['admins'])}'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _line(BuildContext context, String a, String b) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(a, style: AppTypography.label.copyWith(color: c.inkMuted))),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(b, style: latinFigures(AppTypography.bodyStrong).copyWith(color: c.ink)),
          ),
        ],
      ),
    );
  }
}

class _Slice {
  const _Slice(this.label, this.value);
  final String label;
  final int value;
}

const _palette = [
  Color(0xFFC9A75A),
  Color(0xFF0B7A6E),
  Color(0xFF2F62C9),
  Color(0xFFA6482B),
  Color(0xFF6178EA),
  Color(0xFF7D8494),
];

/// حلقة دائرية لتوزيع الباقات مع مفتاح الألوان.
class _Donut extends StatelessWidget {
  const _Donut({required this.slices});
  final List<_Slice> slices;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = slices.fold<int>(0, (a, s) => a + s.value);
    if (total == 0) {
      return Text('لا توجد بيانات بعد', style: AppTypography.label.copyWith(color: c.inkMuted));
    }
    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: CustomPaint(
            painter: _DonutPainter(slices: slices, track: c.track),
            child: Center(
              child: Text('$total', style: latinFigures(AppTypography.title).copyWith(color: c.ink)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < slices.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _palette[i % _palette.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(slices[i].label, style: AppTypography.label.copyWith(color: c.ink)),
                      ),
                      Text('${slices[i].value}',
                          style: latinFigures(AppTypography.label).copyWith(color: c.inkMuted)),
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

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices, required this.track});
  final List<_Slice> slices;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (a, s) => a + s.value);
    final rect = Offset.zero & size;
    final stroke = size.width * 0.16;
    final r = rect.deflate(stroke / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..isAntiAlias = true;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    var start = -math.pi / 2;
    for (var i = 0; i < slices.length; i++) {
      if (slices[i].value == 0) continue;
      final sweep = math.pi * 2 * slices[i].value / total;
      canvas.drawArc(r, start, sweep - 0.02, false, p..color = _palette[i % _palette.length]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.slices != slices;
}

/// أشرطة أفقية.
class _Bars extends StatelessWidget {
  const _Bars({required this.items});
  final List<_Slice> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final max = items.fold<int>(0, (a, s) => s.value > a ? s.value : a);
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Text(items[i].label, style: AppTypography.label.copyWith(color: c.ink)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: LinearProgressIndicator(
                      value: max == 0 ? 0 : items[i].value / max,
                      minHeight: 12,
                      backgroundColor: c.track,
                      color: _palette[i % _palette.length],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 34,
                  child: Text('${items[i].value}',
                      textAlign: TextAlign.end,
                      style: latinFigures(AppTypography.label).copyWith(color: c.inkMuted)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---- المستخدمون -----------------------------------------------------------------

class _Users extends StatefulWidget {
  const _Users({this.filter = 'all'});

  /// all: الكل · admins: المالك والمشرفون · multi: من يُسمح لهم بعدة أجهزة.
  final String filter;

  @override
  State<_Users> createState() => _UsersState();
}

class _UsersState extends State<_Users> {
  final _q = TextEditingController();
  int _gen = 0;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Loader(
      key: ValueKey(_gen),
      load: () => LiveController.instance.adminGet('users'),
      builder: (context, data, reload) {
        final c = context.colors;
        final all = [
          for (final u in (data['users'] as List? ?? const []))
            if (u is Map<String, dynamic>) LiveUser.fromJson(u),
        ];
        final raw = (data['users'] as List? ?? const []).whereType<Map<String, dynamic>>().toList();
        final q = _q.text.trim().toLowerCase();
        final idx = [
          for (var i = 0; i < all.length; i++)
            if ((widget.filter != 'admins' || all[i].isAdmin) &&
                (widget.filter != 'multi' || raw[i]['multiDevice'] == true || all[i].isOwner) &&
                (q.isEmpty ||
                all[i].id.contains(q) ||
                all[i].name.toLowerCase().contains(q) ||
                all[i].email.toLowerCase().contains(q)))
              i,
        ];
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              style: AppTypography.body.copyWith(color: c.ink),
              decoration: _dec(context, 'ابحث بالاسم أو البريد أو ID…'),
            ),
            const SizedBox(height: 8),
            if (widget.filter != 'all')
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  widget.filter == 'admins'
                      ? 'المالك والمشرفون. اضغط على أي مستخدم من «المستخدمون» لمنحه صلاحية مشرف.'
                      : 'الحسابات المسموح لها بعدة أجهزة. اضغط على حساب لفك ربط جهازه أو تغيير الإعداد.',
                  style: AppTypography.caption.copyWith(color: c.inkMuted),
                ),
              ),
            Text('${idx.length} من ${all.length}', style: AppTypography.caption.copyWith(color: c.inkMuted)),
            const SizedBox(height: 8),
            for (final i in idx) ...[
              _userRow(context, all[i], raw[i]),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  Widget _userRow(BuildContext context, LiveUser u, Map<String, dynamic> raw) {
    final c = context.colors;
    final multi = raw['multiDevice'] == true;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: u.disabled ? _danger : c.border),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: () => _actions(context, u, multi),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.name.isNotEmpty ? u.name : (u.guest ? 'زائر' : 'بدون اسم'),
                      style: AppTypography.bodyStrong.copyWith(color: c.ink),
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '${u.id}${u.email.isNotEmpty ? '  ·  ${u.email}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: latinFigures(AppTypography.caption).copyWith(color: c.inkMuted),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _chip(context, u.planName.isEmpty ? u.plan : u.planName, c.goldText),
                        if (u.isOwner) _chip(context, 'المالك', c.goldText),
                        if (u.role == 'admin') _chip(context, 'مشرف', c.goldText),
                        if (multi && !u.isOwner) _chip(context, 'عدة أجهزة', c.inkMuted),
                        if (u.disabled) _chip(context, 'معطّل', _danger),
                      ],
                    ),
                  ],
                ),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(u.balanceLabel, style: latinFigures(AppTypography.label).copyWith(color: c.ink)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String t, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withAlpha(110)),
        ),
        child: Text(t, style: AppTypography.caption.copyWith(color: color)),
      );

  Future<void> _do(BuildContext context, String action, Map<String, dynamic> body, String done) async {
    Navigator.of(context).pop();
    try {
      await LiveController.instance.adminPost(action, body);
      if (!mounted) return;
      _toast(this.context, done);
      setState(() => _gen++);
    } catch (e) {
      if (mounted) _toast(this.context, _err(e));
    }
  }

  void _actions(BuildContext context, LiveUser u, bool multi) {
    final c = context.colors;
    final isOwnerViewer = LiveController.instance.user?.isOwner ?? false;
    final credit = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(u.name.isNotEmpty ? u.name : u.id, style: AppTypography.title.copyWith(color: c.ink)),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text('ID ${u.id}', style: latinFigures(AppTypography.label).copyWith(color: c.inkMuted)),
            ),
            const SizedBox(height: 12),
            if (!u.isOwner)
              _act(ctx, u.disabled ? 'إعادة تفعيل الحساب' : 'تعطيل الحساب فوراً',
                  u.disabled ? Icons.lock_open_rounded : Icons.block_rounded, u.disabled ? _ok : _danger,
                  () => _do(ctx, 'disable', {'id': u.id, 'disabled': !u.disabled},
                      u.disabled ? 'أُعيد تفعيل الحساب' : 'عُطّل الحساب')),
            if (!u.isOwner)
              _act(ctx, multi ? 'جهاز واحد فقط' : 'السماح بعدة أجهزة', Icons.devices_rounded, c.ink,
                  () => _do(ctx, 'devices', {'id': u.id, 'multi': !multi}, 'حُدّثت إعدادات الأجهزة')),
            _act(ctx, 'فك ربط الجهاز (نقل لجهاز جديد)', Icons.phonelink_erase_rounded, c.ink,
                () => _do(ctx, 'devices', {'id': u.id, 'reset': true}, 'فُك ربط الجهاز')),
            if (isOwnerViewer && !u.isOwner && !u.guest)
              _act(ctx, u.role == 'admin' ? 'إلغاء صلاحية المشرف' : 'منح صلاحية مشرف',
                  Icons.admin_panel_settings_rounded, c.goldText,
                  () => _do(ctx, 'role', {'id': u.id, 'role': u.role == 'admin' ? 'user' : 'admin'},
                      'حُدّثت الصلاحية')),
            const SizedBox(height: 10),
            Text('إضافة أو خصم رصيد (دولار، السالب للخصم)', style: AppTypography.label.copyWith(color: c.inkMuted)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: credit,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    textDirection: TextDirection.ltr,
                    style: latinFigures(AppTypography.body).copyWith(color: c.ink),
                    decoration: _dec(ctx, 'مثال: 5'),
                  ),
                ),
                const SizedBox(width: 8),
                GoldButton.primary(
                  label: 'تطبيق',
                  onTap: () {
                    final v = double.tryParse(credit.text.trim());
                    if (v == null || v == 0) return;
                    _do(ctx, 'credit', {'id': u.id, 'usd': v}, 'حُدّث الرصيد');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _act(BuildContext context, String label, IconData icon, Color color, VoidCallback tap) {
    final c = context.colors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label, style: AppTypography.body.copyWith(color: color == c.ink ? c.ink : color)),
      onTap: tap,
    );
  }
}

// ---- الأكواد ---------------------------------------------------------------------

class _Codes extends StatefulWidget {
  const _Codes();

  @override
  State<_Codes> createState() => _CodesState();
}

class _CodesState extends State<_Codes> {
  String _plan = 'regular';
  final _usd = TextEditingController(text: '7');
  final _count = TextEditingController(text: '5');
  List<String> _codes = const [];
  bool _busy = false;

  static const _plans = {'trial': 'التجربة', 'regular': 'العادية', 'top': 'العليا'};

  @override
  void dispose() {
    _usd.dispose();
    _count.dispose();
    super.dispose();
  }

  Future<void> _make() async {
    setState(() => _busy = true);
    try {
      final r = await LiveController.instance.adminPost('codes', {
        'plan': _plan,
        'creditUsd': double.tryParse(_usd.text.trim()) ?? 0,
        'count': int.tryParse(_count.text.trim()) ?? 1,
      });
      if (!mounted) return;
      setState(() => _codes = [for (final x in (r['codes'] as List? ?? const [])) '$x']);
      _toast(context, 'أُنشئ ${_codes.length} كود');
    } catch (e) {
      if (mounted) _toast(context, _err(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _card(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('أكواد المتجر', style: AppTypography.bodyStrong.copyWith(color: c.ink)),
              const SizedBox(height: 4),
              Text('رصيد الكود = 70% من سعر الباقة (مثال: باقة 10 دولارات ← رصيد 7).',
                  style: AppTypography.caption.copyWith(color: c.inkMuted)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in _plans.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: _plan == e.key,
                      onSelected: (_) => setState(() => _plan = e.key),
                      labelStyle: AppTypography.label.copyWith(color: _plan == e.key ? c.goldText : c.ink),
                      selectedColor: c.surfaceSoft,
                      backgroundColor: c.surface,
                      side: BorderSide(color: _plan == e.key ? c.goldLine : c.border),
                      showCheckmark: false,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _usd,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textDirection: TextDirection.ltr,
                      decoration: _dec(context, 'الرصيد \$'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _count,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      decoration: _dec(context, 'العدد'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GoldButton.primary(label: 'إنشاء الأكواد', expand: true, onTap: _busy ? null : _make),
            ],
          ),
        ),
        if (_codes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _card(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final code in _codes)
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText(code, style: latinFigures(AppTypography.body).copyWith(color: c.ink)),
                  ),
                const SizedBox(height: 10),
                GoldButton.secondary(
                  label: 'نسخ كل الأكواد',
                  expand: true,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _codes.join('\n')));
                    _toast(context, 'نُسخت الأكواد');
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---- الإعدادات -------------------------------------------------------------------

class _Settings extends StatefulWidget {
  const _Settings();

  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  final _text = TextEditingController(text: LiveController.instance.referText);
  bool _visible = LiveController.instance.referVisible;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await LiveController.instance.adminPost('config', {'referText': _text.text.trim(), 'referVisible': _visible});
      LiveController.instance.setReferral(_text.text.trim(), _visible);
      if (mounted) _toast(context, 'حُفظت الإعدادات');
    } catch (e) {
      if (mounted) _toast(context, _err(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _card(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('نص الإحالة تحت بطاقة المستخدم', style: AppTypography.bodyStrong.copyWith(color: c.ink)),
              const SizedBox(height: 10),
              TextField(
                controller: _text,
                minLines: 2,
                maxLines: 5,
                style: AppTypography.body.copyWith(color: c.ink),
                decoration: _dec(context, 'مثال: ادعُ صديقاً واحصل على…'),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _visible,
                activeColor: c.goldLine,
                onChanged: (v) => setState(() => _visible = v),
                title: Text('إظهار النص في التطبيق', style: AppTypography.body.copyWith(color: c.ink)),
              ),
              GoldButton.primary(label: 'حفظ', expand: true, onTap: _busy ? null : _save),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'إعدادات أكثر (حدود الباقات، نماذج كل باقة) تُضاف هنا تباعاً.',
          style: AppTypography.caption.copyWith(color: c.inkMuted),
        ),
      ],
    );
  }
}

// ---- السجل -----------------------------------------------------------------------

class _Log extends StatelessWidget {
  const _Log();

  static const _acts = {
    'disable': 'تعطيل',
    'enable': 'إعادة تفعيل',
    'activate': 'تفعيل كود',
    'login-issued': 'رمز دخول',
    'codes': 'إنشاء أكواد',
    'credit': 'تعديل رصيد',
    'config': 'إعدادات',
    'credentials': 'بريد وكلمة مرور',
    'signup': 'حساب جديد',
    'device-reset': 'فك ربط جهاز',
    'multi-device': 'إعداد الأجهزة',
    'role': 'صلاحيات',
  };

  @override
  Widget build(BuildContext context) {
    return _Loader(
      load: () => LiveController.instance.adminGet('log'),
      builder: (context, data, _) {
        final c = context.colors;
        final rows = (data['log'] as List? ?? const []).whereType<Map<String, dynamic>>().toList();
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: rows.length,
          separatorBuilder: (_, __) => Divider(color: c.border, height: 1),
          itemBuilder: (context, i) {
            final r = rows[i];
            final ts = '${r['ts'] ?? ''}'.replaceFirst('T', ' ');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_acts[r['action']] ?? r['action']} · ${r['who']}',
                      style: AppTypography.bodyStrong.copyWith(color: c.ink)),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      '${ts.length > 16 ? ts.substring(0, 16) : ts}  ${r['detail'] ?? ''}',
                      style: latinFigures(AppTypography.caption).copyWith(color: c.inkMuted),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

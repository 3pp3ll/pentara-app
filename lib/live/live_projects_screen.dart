import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/glyph.dart';
import '../widgets/gold_button.dart';
import '../widgets/project_card.dart' show latinFigures;
import 'live_api.dart';
import 'live_session.dart';
import 'live_stats.dart';
import 'scroll_top.dart';

/// «المشاريع»: جلساتك الحقيقية المحفوظة في السيرفر. الضغط يفتحها في الطاولة.
class LiveProjectsScreen extends StatefulWidget {
  const LiveProjectsScreen({super.key, required this.onOpened, required this.onNew});

  /// بعد فتح جلسة: الانتقال لتبويب الطاولة.
  final VoidCallback onOpened;
  final VoidCallback onNew;

  @override
  State<LiveProjectsScreen> createState() => _LiveProjectsScreenState();
}

class _LiveProjectsScreenState extends State<LiveProjectsScreen> {
  final TextEditingController _q = TextEditingController();
  final ScrollController _scroll = ScrollController();
  LiveOutput? _filter;
  bool _requested = false;

  LiveHub get hub => LiveHub.instance;

  @override
  void initState() {
    super.initState();
    _maybeLoad();
    LiveController.instance.addListener(_maybeLoad);
  }

  void _maybeLoad() {
    if (_requested || !LiveController.instance.isSignedIn) return;
    _requested = true;
    hub.loadList();
  }

  @override
  void dispose() {
    LiveController.instance.removeListener(_maybeLoad);
    _q.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _open(SessionMeta m) async {
    final ok = await hub.open(m.id);
    if (!mounted) return;
    if (ok) {
      widget.onOpened();
    } else {
      _toast('تعذّر فتح الجلسة. تحقق من الاتصال');
    }
  }

  Future<void> _delete(SessionMeta m) async {
    final c = context.colors;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('حذف الجلسة؟', style: AppTypography.title.copyWith(color: c.ink)),
        content: Text('«${m.title}» ستُحذف نهائياً.', style: AppTypography.body.copyWith(color: c.inkMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: AppTypography.label.copyWith(color: c.ink)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('حذف', style: AppTypography.label.copyWith(color: const Color(0xFFA8322E))),
          ),
        ],
      ),
    );
    if (yes == true) {
      await hub.delete(m.id);
      if (mounted) _toast('حُذفت الجلسة');
    }
  }

  void _toast(String m) {
    final c = context.colors;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.ink,
        content: Text(m, style: AppTypography.label.copyWith(color: c.bg)),
      ));
  }

  static const _months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  String _when(DateTime d) {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (days == 0) return 'اليوم';
    if (days == 1) return 'أمس';
    return '${d.day} ${_months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge([hub, LiveController.instance]),
        builder: (context, _) {
          final signedIn = LiveController.instance.isSignedIn;
          final q = _q.text.trim();
          final rows = hub.sessions.where((m) {
            if (_filter != null && m.output != _filter) return false;
            return q.isEmpty || m.title.contains(q);
          }).toList();

          return Stack(
            children: [
              RefreshIndicator(
            color: c.goldLine,
            onRefresh: hub.loadList,
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('المشاريع', style: AppTypography.displayL.copyWith(color: c.ink)),
                    ),
                    if (signedIn)
                      GoldButton.secondary(label: 'جلسة جديدة', onTap: widget.onNew),
                  ],
                ),
                const SizedBox(height: 16),
                const CategorySummary(),
                const SizedBox(height: 16),
                if (!signedIn)
                  Text(
                    'أنشئ حسابك من «حسابي» لتظهر جلساتك المحفوظة هنا.',
                    style: AppTypography.body.copyWith(color: c.inkMuted),
                  )
                else ...[
                  TextField(
                    controller: _q,
                    onChanged: (_) => setState(() {}),
                    style: AppTypography.body.copyWith(color: c.ink),
                    decoration: InputDecoration(
                      hintText: 'ابحث في جلساتك…',
                      hintStyle: AppTypography.body.copyWith(color: c.inkMuted),
                      filled: true,
                      fillColor: c.surface,
                      prefixIcon: Icon(Icons.search_rounded, color: c.goldText),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(color: c.goldLine),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(color: c.goldLine.withAlpha(170), width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(color: c.goldLine, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(context, 'الكل', Icons.apps_rounded, GlyphTone.gold, _filter == null,
                          () => setState(() => _filter = null)),
                      for (final o in LiveOutput.values)
                        _chip(context, o.label, CategorySummary.icons[o]!, outputTone(o.index), _filter == o,
                            () => setState(() => _filter = o)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (hub.loading && hub.sessions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator(color: c.goldLine)),
                    )
                  else if (hub.error != null && hub.sessions.isEmpty)
                    Text(hub.error!, style: AppTypography.label.copyWith(color: const Color(0xFFA8322E)))
                  else if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        hub.sessions.isEmpty
                            ? 'لا توجد جلسات بعد. ابدأ أول جلسة من «جلسة جديدة».'
                            : 'لا توجد نتائج مطابقة.',
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(color: c.inkMuted),
                      ),
                    )
                  else
                    for (final m in rows) ...[
                      _card(context, m),
                      const SizedBox(height: 10),
                    ],
                ],
              ],
            ),
              ),
              ScrollTopButton(controller: _scroll),
            ],
          );
        },
      ),
    );
  }

  /// فلتر بلون أيقونته في الصف العلوي: المختار متدرج، والباقي بحد ولون النوع.
  Widget _chip(BuildContext context, String label, IconData icon, GlyphTone tone, bool on, VoidCallback tap) {
    final c = context.colors;
    final ink = tone.shadow;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: tap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            gradient: on ? tone.gradient : null,
            color: on ? null : c.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? Colors.transparent : ink.withAlpha(150)),
            boxShadow: on ? [BoxShadow(color: ink.withAlpha(60), blurRadius: 10, offset: const Offset(0, 4))] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: on ? Colors.white : ink),
              const SizedBox(width: 6),
              Text(label,
                  style: AppTypography.label
                      .copyWith(color: on ? Colors.white : c.ink, fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, SessionMeta m) {
    final c = context.colors;
    final live = hub.current.id == m.id && hub.current.running;
    final done = !live && m.status == 'done';
    // لون الحالة: مكتملة أخضر، جارية أزرق، متوقفة كهرماني.
    final status = live ? c.info : (done ? c.ok : c.warn);
    final statusLabel = live ? 'جارية' : (done ? 'مكتملة' : 'متوقفة');
    return Material(
      color: Color.alphaBlend(status.bg.withAlpha(70), c.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: status.ink.withAlpha(140), width: 1.3),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(m),
        onLongPress: () => _delete(m),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Glyph(CategorySummary.icons[m.output]!, tone: outputTone(m.output.index), size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong.copyWith(color: c.ink)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: status.bg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusLabel,
                            style: AppTypography.caption.copyWith(color: status.ink, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${m.output.label} · ${_when(m.createdAt)}',
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(color: c.inkMuted),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            formatMicros(m.costMicros),
                            style: latinFigures(AppTypography.caption).copyWith(color: c.inkMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'حذف',
                onPressed: () => _delete(m),
                icon: Icon(Icons.delete_outline_rounded, color: c.inkMuted, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// «آخر المشاريع» في الرئيسية: آخر ثلاث جلسات حقيقية.
class LiveRecentSessions extends StatelessWidget {
  const LiveRecentSessions({super.key, required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: Listenable.merge([LiveHub.instance, LiveController.instance]),
      builder: (context, _) {
        final list = LiveHub.instance.sessions.take(3).toList();
        if (list.isEmpty) {
          return Text(
            LiveController.instance.isSignedIn
                ? 'لا توجد جلسات بعد. اضغط «مشروع جديد» لتبدأ أول جلسة.'
                : 'أنشئ حسابك من «حسابي» ثم ابدأ أول جلسة.',
            style: AppTypography.body.copyWith(color: c.inkMuted),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < list.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              Material(
                color: c.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: c.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onOpen(list[i].id),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Glyph(CategorySummary.icons[list[i].output]!, tone: outputTone(list[i].output.index), size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(list[i].title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodyStrong.copyWith(color: c.ink)),
                              const SizedBox(height: 4),
                              Text(list[i].output.label,
                                  style: AppTypography.caption.copyWith(color: c.inkMuted)),
                            ],
                          ),
                        ),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            formatMicros(list[i].costMicros),
                            style: latinFigures(AppTypography.caption).copyWith(color: c.goldText),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

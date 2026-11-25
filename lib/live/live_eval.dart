import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/glyph.dart';
import '../widgets/gold_button.dart';
import '../widgets/project_card.dart' show latinFigures;
import 'live_api.dart';
import 'live_session.dart';
import 'scroll_top.dart';

/// معايير التقييم (نفس صفحة المختبر).
const List<String> kEvalCriteria = [
  'إجابات مستقلة في الجولة الأولى',
  'اكتشاف الأخطاء',
  'مناقشة نقاط الخلاف',
  'تحسن الخلاصة النهائية',
  'ملاءمة التكلفة والمدة',
  'دقة المعلومات وخلوّها من الأخطاء',
  'وضوح الخلاصة وسهولة استخدامها',
  'الالتزام بالطلب ونوع المخرج',
  'جودة التصميم أو الكود (إن وُجد)',
  'فائدة فلتر الإجماع والتدقيق',
];

const Map<String, String> kEvalUse = {
  'yes': 'نعم، كما هي',
  'edit': 'نعم، بعد تعديلات',
  'no': 'لا',
};

const Map<String, String> kEvalVerify = {
  'not_run': 'لم يُختبر عملياً',
  'tested_failed': 'نُفذت اختبارات وفشلت',
  'tested_passed': 'نجح اختبار محلي (بتوثيق)',
  'independent': 'تحقق مستقل موثق',
  'not_applicable': 'لا ينطبق (مخرج غير برمجي)',
};

const Color _star = Color(0xFFE0A800);

String starsText(int n) => n <= 0 ? '—' : '★' * n + '☆' * (5 - n);

/// نافذة تقييم الجلسة: نجوم، هل ستستخدم النتيجة، المعايير العشرة، التحقق، ملاحظة.
Future<void> showEvalSheet(BuildContext context, LiveSession s) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.colors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _EvalSheet(session: s),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(behavior: SnackBarBehavior.floating, content: Text('✓ تم حفظ التقييم')));
  }
}

class _EvalSheet extends StatefulWidget {
  const _EvalSheet({required this.session});
  final LiveSession session;

  @override
  State<_EvalSheet> createState() => _EvalSheetState();
}

class _EvalSheetState extends State<_EvalSheet> {
  late int stars;
  late String use;
  late String verify;
  late List<bool> checks;
  late final TextEditingController note;
  bool saving = false;
  String? msg;

  @override
  void initState() {
    super.initState();
    final e = widget.session.eval;
    stars = e?.stars ?? 0;
    use = e?.use ?? '';
    verify = e?.verify ??
        (widget.session.output == LiveOutput.appIdea || widget.session.output == LiveOutput.web
            ? 'not_run'
            : 'not_applicable');
    checks = List<bool>.generate(kEvalCriteria.length, (i) => e != null && i < e.checks.length && e.checks[i]);
    note = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (stars == 0) {
      setState(() => msg = 'اختر التقييم العام بالنجوم');
      return;
    }
    setState(() {
      saving = true;
      msg = null;
    });
    final s = widget.session;
    s.eval = LiveEval(
      stars: stars,
      use: use,
      verify: verify,
      checks: List.of(checks),
      note: note.text.trim(),
      date: DateTime.now(),
    );
    await s.save();
    await LiveHub.instance.loadList();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = widget.session;
    final score = checks.where((x) => x).length;
    Widget card(String title, List<Widget> kids) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: AppTypography.bodyStrong.copyWith(color: c.ink)),
            const SizedBox(height: 10),
            ...kids,
          ]),
        );
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.body.copyWith(color: c.inkMuted),
          filled: true,
          fillColor: c.bg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
          enabledBorder:
              OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
        );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Glyph(Icons.star_rounded, tone: GlyphTone.gold, size: 38),
              const SizedBox(width: 10),
              Expanded(child: Text('تقييم الجلسة', style: AppTypography.title.copyWith(color: c.ink))),
              IconButton(onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.close_rounded, color: c.inkMuted)),
            ]),
            const SizedBox(height: 4),
            Text('${s.title} · ${s.output.label}',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.caption.copyWith(color: c.inkMuted)),
            const SizedBox(height: 14),
            card('التقييم العام', [
              Row(
                children: [
                  for (var n = 1; n <= 5; n++)
                    IconButton(
                      tooltip: '$n من 5',
                      onPressed: () => setState(() => stars = n),
                      icon: Icon(n <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: n <= stars ? _star : c.border, size: 34),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: use.isEmpty ? null : use,
                decoration: deco('هل ستستخدم النتيجة؟'),
                items: [for (final e in kEvalUse.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setState(() => use = v ?? ''),
              ),
            ]),
            card('معايير التقييم', [
              for (var i = 0; i < kEvalCriteria.length; i++)
                CheckboxListTile(
                  value: checks[i],
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: c.goldLine,
                  title: Text(kEvalCriteria[i], style: AppTypography.label.copyWith(color: c.ink)),
                  onChanged: (v) => setState(() => checks[i] = v ?? false),
                ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: verify,
                isExpanded: true,
                decoration: deco('التحقق من المنتج النهائي'),
                items: [for (final e in kEvalVerify.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setState(() => verify = v ?? 'not_run'),
              ),
              const SizedBox(height: 6),
              Text(
                'الدرجة تقييمك لعناصر الجلسة، ولا تثبت نجاح بناء التطبيق أو الكود. اختر مستوى تحقق موثقاً فقط.',
                style: AppTypography.caption.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                minLines: 2,
                maxLines: 5,
                style: AppTypography.body.copyWith(color: c.ink),
                decoration: deco('ملاحظات (اختياري): وش لاحظت؟ وش ناقص؟'),
              ),
            ]),
            Row(children: [
              Text('الدرجة: ', style: AppTypography.body.copyWith(color: c.inkMuted)),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text('$score/${kEvalCriteria.length}',
                    style: latinFigures(AppTypography.bodyStrong).copyWith(color: c.ink)),
              ),
              const Spacer(),
              GoldButton.primary(label: saving ? 'جاري الحفظ…' : 'حفظ التقييم', onTap: saving ? null : _save),
            ]),
            if (msg != null) ...[
              const SizedBox(height: 8),
              Text(msg!, style: AppTypography.label.copyWith(color: c.danger.ink)),
            ],
          ],
        ),
      ),
    );
  }
}

/// شارة مختصرة للتقييم على بطاقات المشاريع: ★4 · 8/10.
class EvalBadge extends StatelessWidget {
  const EvalBadge(this.m, {super.key});
  final SessionMeta m;

  @override
  Widget build(BuildContext context) {
    if (m.stars <= 0) return const SizedBox.shrink();
    final c = context.colors;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        '★${m.stars}${m.evalTotal > 0 ? ' · ${m.evalScore}/${m.evalTotal}' : ''}',
        style: latinFigures(AppTypography.caption).copyWith(color: c.ink.withAlpha(220), fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// تحليل نتائج التقييم (لجلسات الحساب): نفس تبويب «تحليل النتائج» في صفحة المختبر.
class LiveEvalAnalysis extends StatelessWidget {
  const LiveEvalAnalysis({super.key, required this.onOpen});
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final all = LiveHub.instance.sessions.where((m) => m.stars > 0).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (all.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border),
        ),
        child: Text('ما فيه تقييمات للحين. افتح أي جلسة واضغط «⭐ قيّم الجلسة» تحت الخلاصة.',
            style: AppTypography.label.copyWith(color: c.inkMuted)),
      );
    }
    double avg(Iterable<num> xs) => xs.isEmpty ? 0 : xs.fold<num>(0, (a, b) => a + b) / xs.length;
    double pct(SessionMeta m) => m.evalTotal == 0 ? 0 : m.evalScore / m.evalTotal * 100;
    final n = all.length;
    final avgPct = avg(all.map(pct));
    final avgStars = avg(all.map((m) => m.stars));
    final used = all.where((m) => m.evalUse == 'yes' || m.evalUse == 'edit').length;
    // نسبة تحقق كل معيار.
    final rates = <(String, double)>[];
    for (var i = 0; i < kEvalCriteria.length; i++) {
      final have = all.where((m) => i < m.evalChecks.length).toList();
      if (have.isEmpty) continue;
      rates.add((kEvalCriteria[i], have.where((m) => m.evalChecks[i]).length / have.length));
    }
    final sorted = [...rates]..sort((a, b) => a.$2.compareTo(b.$2));
    final best = [...all]..sort((a, b) {
        final d = pct(b).compareTo(pct(a));
        if (d != 0) return d;
        final s = b.stars.compareTo(a.stars);
        return s != 0 ? s : a.costMicros.compareTo(b.costMicros);
      });
    final byOut = <LiveOutput, List<SessionMeta>>{};
    for (final m in all) {
      byOut.putIfAbsent(m.output, () => []).add(m);
    }
    final last = all.length > 12 ? all.sublist(all.length - 12) : all;

    Widget kpi(String label, String v, IconData icon, GlyphTone tone) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Row(children: [
              Glyph(icon, tone: tone, size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(color: c.inkMuted)),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(v, style: latinFigures(AppTypography.bodyStrong).copyWith(color: c.ink, fontSize: 17)),
                  ),
                ]),
              ),
            ]),
          ),
        );
    Widget box(String title, Widget child, {Widget? action}) => Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(title, style: AppTypography.bodyStrong.copyWith(color: c.ink))),
              if (action != null) action,
            ]),
            const SizedBox(height: 10),
            child,
          ]),
        );
    Widget bar(String label, double r, String trail) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(
              width: 150,
              child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(color: c.ink)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: r.clamp(0, 1).toDouble(),
                  minHeight: 10,
                  color: r >= .8 ? c.ok.ink : (r >= .6 ? c.goldLine : c.warn.ink),
                  backgroundColor: c.track,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(trail, textAlign: TextAlign.right,
                    style: latinFigures(AppTypography.caption).copyWith(color: c.inkMuted)),
              ),
            ),
          ]),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          kpi('التقييمات', '$n', Icons.fact_check_rounded, GlyphTone.gold),
          const SizedBox(width: 8),
          kpi('متوسط الدرجة', '${avgPct.round()}%', Icons.speed_rounded, GlyphTone.emerald),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          kpi('التقييم العام', '${avgStars.toStringAsFixed(1)} ★', Icons.star_rounded, GlyphTone.copper),
          const SizedBox(width: 8),
          kpi('استخدمت النتيجة', '${(used / n * 100).round()}%', Icons.task_alt_rounded, GlyphTone.blue),
        ]),
        if (sorted.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surfaceSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.goldLine),
            ),
            child: Text(
              '${n < 3 ? 'التقييمات قليلة؛ الأنماط تتضح بعد 3 تقييمات أو أكثر. ' : ''}'
              'أقوى معيار: ${sorted.last.$1} (${(sorted.last.$2 * 100).round()}%) · '
              'أضعف معيار: ${sorted.first.$1} (${(sorted.first.$2 * 100).round()}%) · '
              'أفضل جلسة: ${best.first.title} (${pct(best.first).round()}% · ${best.first.stars}★ بتكلفة ${formatMicros(best.first.costMicros)})',
              style: AppTypography.label.copyWith(color: c.ink),
            ),
          ),
        box('نسبة تحقق كل معيار', Column(children: [for (final r in rates) bar(r.$1, r.$2, '${(r.$2 * 100).round()}%')])),
        box(
          'درجة كل جلسة${n > 12 ? ' (آخر 12)' : ''}',
          Column(children: [
            for (final m in last.reversed)
              InkWell(
                onTap: () => onOpen(m.id),
                child: bar(m.title, pct(m) / 100, '${pct(m).round()}% ${m.stars}★'),
              ),
          ]),
        ),
        box(
          'المقارنة حسب نوع المخرج',
          Table(
            columnWidths: const {0: FlexColumnWidth(2.2)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(children: [
                for (final h in ['النوع', 'تقييمات', 'الدرجة', 'النجوم', 'التكلفة'])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(h, style: AppTypography.caption.copyWith(color: c.inkMuted, fontWeight: FontWeight.w600)),
                  ),
              ]),
              for (final e in byOut.entries)
                TableRow(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(e.key.label, style: AppTypography.label.copyWith(color: c.ink)),
                  ),
                  Text('${e.value.length}', style: latinFigures(AppTypography.label).copyWith(color: c.ink)),
                  Text('${avg(e.value.map(pct)).round()}%', style: latinFigures(AppTypography.label).copyWith(color: c.ink)),
                  Text(avg(e.value.map((m) => m.stars)).toStringAsFixed(1),
                      style: latinFigures(AppTypography.label).copyWith(color: c.ink)),
                  Text(formatMicros(avg(e.value.map((m) => m.costMicros)).round()),
                      style: latinFigures(AppTypography.label).copyWith(color: c.ink)),
                ]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: PopupMenuButton<ExportFormat>(
            tooltip: 'تصدير التقييمات',
            onSelected: (f) => exportText(context, 'تقرير التقييم', evalReport(all), format: f),
            itemBuilder: (_) => const [
              PopupMenuItem(value: ExportFormat.word, child: Text('Word')),
              PopupMenuItem(value: ExportFormat.pdf, child: Text('PDF')),
              PopupMenuItem(value: ExportFormat.txt, child: Text('نص TXT')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: c.goldLine),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.download_rounded, size: 18, color: c.goldText),
                const SizedBox(width: 6),
                Text('تصدير التقييمات', style: AppTypography.label.copyWith(color: c.goldText)),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

/// تقرير التقييمات كنص Markdown بجداول (يتحول Word/PDF بنفس آلية الخلاصة).
String evalReport(List<SessionMeta> all) {
  String cell(String s) => s.replaceAll('|', '/').replaceAll('\n', ' ');
  final b = StringBuffer('# تقرير تقييم جلسات بنتارا\n\nعدد التقييمات: ${all.length}\n\n');
  b.writeln('| الجلسة | التاريخ | النوع | النجوم | الدرجة | الاستخدام | التحقق | التكلفة | ملاحظة |');
  b.writeln('|---|---|---|---|---|---|---|---|---|');
  for (final m in all.reversed) {
    final d = m.createdAt;
    b.writeln('| ${cell(m.title)} | ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '| ${m.output.label} | ${m.stars} | ${m.evalScore}/${m.evalTotal} | ${kEvalUse[m.evalUse] ?? '—'} '
        '| ${kEvalVerify[m.evalVerify] ?? '—'} | ${formatMicros(m.costMicros)} | ${cell(m.evalNote)} |');
  }
  b.writeln('\n## نسبة تحقق كل معيار\n');
  b.writeln('| المعيار | النسبة |');
  b.writeln('|---|---|');
  for (var i = 0; i < kEvalCriteria.length; i++) {
    final have = all.where((m) => i < m.evalChecks.length).toList();
    if (have.isEmpty) continue;
    b.writeln('| ${kEvalCriteria[i]} | ${(have.where((m) => m.evalChecks[i]).length / have.length * 100).round()}% |');
  }
  return b.toString();
}

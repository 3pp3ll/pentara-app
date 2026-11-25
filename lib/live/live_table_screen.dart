import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/mock_data.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/glyph.dart';
import '../widgets/gold_button.dart';
import '../widgets/member_avatar.dart';
import '../widgets/project_card.dart' show latinFigures;
import 'live_account_card.dart';
import 'live_api.dart';
import 'live_eval.dart';
import 'live_session.dart';
import 'doc_export.dart';
import 'live_stats.dart';
import 'rich_text_view.dart';
import 'scroll_top.dart';

/// الطاولة الحقيقية: المستخدم يكتب فكرته، والأعضاء الخمسة يتناقشون عبر السيرفر،
/// ويستطيع التدخل أثناء النقاش، ثم يكتب رئيس الجلسة الخلاصة ويطبّق التعديلات.
/// [embedded]: داخل تبويب «الطاولة» (بلا زر رجوع).
class LiveTableScreen extends StatefulWidget {
  const LiveTableScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<LiveTableScreen> createState() => _LiveTableScreenState();
}

class _LiveTableScreenState extends State<LiveTableScreen> {
  final TextEditingController _idea = TextEditingController();
  final TextEditingController _note = TextEditingController();

  /// صيغة الرد بعد الخلاصة: null = تعديل الخلاصة.
  LiveOutput? _replyAs;
  final TextEditingController _sources = TextEditingController();
  final ScrollController _scroll = ScrollController();
  String _shownId = '';

  LiveHub get hub => LiveHub.instance;
  LiveSession get _s => hub.current;

  @override
  void initState() {
    super.initState();
    _syncFields();
    hub.addListener(_syncFields);
    // حارس: إذا ما تقدّمت الجلسة 5 دقائق (انقطع الاتصال أو نام الجوال) تتوقف ويظهر «استمرار».
    _watchdog = Timer.periodic(const Duration(seconds: 20), (_) {
      final s = hub.current;
      if (s.running && DateTime.now().difference(s.lastProgress) > const Duration(minutes: 5)) {
        s.interrupt('انقطعت الجلسة بدون رد لأكثر من 5 دقائق. اضغط «استمرار» لتكمل من نفس النقطة.');
      }
    });
  }

  Timer? _watchdog;

  @override
  void dispose() {
    _watchdog?.cancel();
    hub.removeListener(_syncFields);
    _idea.dispose();
    _note.dispose();
    _sources.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Member _member(MemberId id) =>
      MockData.members.firstWhere((m) => m.id == id, orElse: () => MockData.members.first);

  /// عند تبديل الجلسة (جديدة أو مفتوحة من المشاريع) نعبّئ خانة الفكرة منها.
  void _syncFields() {
    if (_shownId == _s.id) return;
    _shownId = _s.id;
    _idea.text = _s.idea;
    _sources.text = _s.sources;
    _note.clear();
  }

  Future<void> _start() async {
    FocusScope.of(context).unfocus();
    final s = _s;
    if (_loading.isNotEmpty) {
      _toast('انتظر حتى يكتمل تحميل الملفات');
      return;
    }
    s.idea = _idea.text;
    if (s.idea.trim().length < 10) {
      _toast('اكتب فكرتك بتفصيل أكثر (10 أحرف على الأقل)');
      return;
    }
    final live = LiveController.instance;
    // زائر: تجربة واحدة قبل التسجيل.
    if (live.user == null) {
      final ok = await live.ensureGuest();
      if (!mounted) return;
      if (!ok) {
        _toast(live.error ?? 'تعذّر بدء التجربة');
        return;
      }
    }
    if (_blocked) {
      setState(() {});
      return;
    }
    final msg = _outputBlock(s.output);
    if (msg != null) {
      _toast(msg);
      return;
    }
    await s.start();
    if (!mounted || !identical(s, _s)) return;
    if (s.phase == LivePhase.done) {
      _toast('اكتملت الجلسة وحُفظت في «المشاريع»');
      _toBottom();
    } else if (s.phase == LivePhase.failed) {
      _toast('توقفت الجلسة: ${s.error ?? ''}');
    }
  }

  /// إرفاق ملفات نصية (txt, md, csv, json, html…) تُقرأ مع الفكرة.
  /// ملفات جاري تحميلها: الاسم ← نسبة التقدم (0..1).
  final Map<String, double> _loading = {};

  Future<void> _pickFiles() async {
    final s = _s;
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withReadStream: true,
      type: FileType.custom,
      allowedExtensions: const ['txt', 'md', 'csv', 'json', 'html', 'xml', 'tsv', 'log', 'dart', 'js', 'css', 'yaml'],
    );
    if (res == null || !mounted) return;
    setState(() {
      for (final f in res.files) {
        _loading[f.name] = 0;
      }
    });
    var used = s.attachments.fold<int>(0, (a, x) => a + x.text.length);
    var skipped = 0;
    var added = 0;
    for (final f in res.files) {
      final buf = BytesBuilder(copy: false);
      try {
        final stream = f.readStream;
        if (stream != null) {
          var last = DateTime.now();
          await for (final chunk in stream) {
            buf.add(chunk);
            final now = DateTime.now();
            if (f.size > 0 && mounted && now.difference(last).inMilliseconds > 60) {
              last = now;
              setState(() => _loading[f.name] = (buf.length / f.size).clamp(0.0, 1.0).toDouble());
            }
          }
        } else if (f.bytes != null) {
          buf.add(f.bytes!);
        }
      } catch (_) {}
      if (!mounted) return;
      _loading.remove(f.name);
      var text = utf8.decode(buf.takeBytes(), allowMalformed: true).trim();
      if (text.isEmpty) {
        setState(() {});
        continue;
      }
      final room = LiveAttachment.maxTotal - used;
      if (room <= 500) {
        skipped++;
        setState(() {});
        continue;
      }
      final cap = room < LiveAttachment.maxChars ? room : LiveAttachment.maxChars;
      if (text.length > cap) text = '${text.substring(0, cap)}\n…(اختُصر الملف)';
      s.attachments.add(LiveAttachment(name: f.name, text: text));
      used += text.length;
      added++;
      setState(() {});
    }
    if (skipped > 0) {
      _toast('تجاوزت الحد المسموح للمرفقات؛ لم يُضف $skipped ملف');
    } else if (added > 0) {
      _toast(added == 1 ? '✓ اكتمل تحميل الملف' : '✓ اكتمل تحميل $added ملفات');
    }
  }

  Future<void> _send() async {
    final t = _note.text.trim();
    if (t.isEmpty) return;
    FocusScope.of(context).unfocus();
    final s = _s;
    if (s.discussing) {
      s.addNote(t);
      _note.clear();
      _toast('وصلت مداخلتك للطاولة');
      return;
    }
    if (s.phase == LivePhase.done) {
      final fmt = _replyAs == s.output ? null : _replyAs;
      if (fmt != null) {
        final msg = _outputBlock(fmt);
        if (msg != null) {
          _toast(msg);
          return;
        }
      }
      _note.clear();
      _toBottom();
      await s.revise(t, fmt: fmt);
      if (!mounted || !identical(s, _s)) return;
      final last = s.revisions.isEmpty ? null : s.revisions.last;
      final ok = fmt == null ? 'طُبّق التعديل وحُفظ' : 'وصل الرد بصيغة ${fmt.label} وحُفظ';
      _toast(last?.error == null ? ok : 'تعذّر الطلب: ${last!.error}');
      _toBottom();
    }
  }

  void _newSession() {
    if (_s.running) {
      _toast('انتظر حتى تكتمل الجلسة الحالية');
      return;
    }
    hub.newSession();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = ListenableBuilder(
      listenable: hub,
      builder: (context, _) {
        return ListenableBuilder(
          listenable: Listenable.merge([_s, LiveController.instance]),
          builder: (context, _) => _page(context),
        );
      },
    );
    if (widget.embedded) return SafeArea(bottom: false, child: body);
    return Scaffold(backgroundColor: c.bg, body: SafeArea(child: body));
  }

  /// حدود المخرجات: تطبيق فلاتر للباقات فقط، وصفحة الويب تحتاج رصيداً أكبر من 5 دولار.
  String? _outputBlock(LiveOutput o) {
    final u = LiveController.instance.user;
    if (u == null) return null;
    if (o == LiveOutput.appIdea && !u.guest && !u.hasPlan) return 'تطبيقات فلاتر متاحة في الباقات فقط';
    if (o == LiveOutput.web && u.balanceMicros <= 5000000) return 'المبلغ لا يكفي لإنشاء الطلب';
    return null;
  }

  /// لا يمكن بدء جلسة جديدة: الزائر استخدم تجربته، أو المسجّل بلا باقة.
  bool get _blocked {
    final live = LiveController.instance;
    if (!live.configured) return true;
    if (live.isGuest) {
      return LiveHub.instance.sessions.isNotEmpty || (live.user?.balanceMicros ?? 0) <= 0;
    }
    // بدون باقة يكفي وجود رصيد (يضيفه المالك للتجربة) فيعمل بالنماذج العادية.
    if (live.isRegistered) return !(live.user?.hasPlan ?? false) && (live.user?.balanceMicros ?? 0) <= 0;
    return false; // غير مسجّل: يبدأ كزائر
  }

  String get _blockedText {
    final live = LiveController.instance;
    if (live.isGuest) {
      return 'انتهت تجربتك المجانية (مشروع واحد). سجّل حسابك لتحفظ جلستك وتكمل بمشاريع أكثر.';
    }
    return 'رصيدك انتهى. فعّل باقتك بالكود من المتجر لتبدأ جلسات جديدة.';
  }

  Widget _page(BuildContext context) {
    final c = context.colors;
    final s = _s;
    final live = LiveController.instance;
    final canRun = !_blocked || s.phase != LivePhase.idle;
    // الزائر: مداخلة أثناء النقاش فقط، والتعديل بعد التسجيل.
    final collapsed = hub.collapsed && s.phase != LivePhase.idle;
    final showInput = !collapsed &&
        live.user != null &&
        (s.discussing || (live.isRegistered && (s.phase == LivePhase.done || s.phase == LivePhase.revising)));

    return Column(
      children: [
        _header(context),
        Expanded(
          child: Stack(
            children: [
              // تحديد ونسخ أي نص في الجلسة (الأعضاء والخلاصة وطلباتك) باللمس المطوّل أو السحب.
              SelectionArea(
                child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              if (collapsed)
                ..._sessionList(context)
              else if (!canRun && s.phase == LivePhase.idle) ...[
                Text(_blockedText, style: AppTypography.body.copyWith(color: c.inkMuted)),
                const SizedBox(height: 12),
                const LiveAccountCard(),
              ] else ...[
                if (s.phase != LivePhase.idle) ...[
                  _sessionTile(context, id: s.id, title: s.title, output: s.output, status: _statusOf(s),
                      when: s.createdAt, open: true, onTap: hub.collapse),
                  const SizedBox(height: 10),
                ],
                if (s.phase == LivePhase.idle) _composer(context) else _ideaCard(context),
                if (s.phase != LivePhase.idle) ...[
                  const SizedBox(height: 20),
                  _phaseBar(context),
                  const SizedBox(height: 12),
                  for (final e in s.entries) ...[
                    _bubble(context, e),
                    const SizedBox(height: 10),
                  ],
                  if (s.notes.isNotEmpty) ...[
                    for (final n in s.notes) ...[
                      _userBubble(context, 'مداخلتك', n),
                      const SizedBox(height: 10),
                    ],
                  ],
                  // حالة واضحة أسفل الجلسة دائماً وهي تعمل: من باقي، وزر إيقاف.
                  if (s.discussing) _runningBar(context, s),
                  if (s.phase == LivePhase.summary) _waiting(context, 'رئيس الجلسة يكتب الخلاصة…'),
                  if (s.summary.isNotEmpty) _summary(context, s.summary, 'الخلاصة الموحّدة', cut: s.summaryCut),
                  for (final r in s.revisions) ...[
                    const SizedBox(height: 14),
                    _userBubble(context, r.output == null ? 'طلب تعديل' : 'طلب جديد · ${r.output!.label}', r.request),
                    const SizedBox(height: 10),
                    if (r.pending)
                      _waiting(context,
                          r.output == null ? 'رئيس الجلسة يطبّق التعديل…' : 'رئيس الجلسة يكتب الرد (${r.output!.label})…')
                    else if (r.error != null)
                      Text('تعذّر التعديل: ${r.error}',
                          style: AppTypography.label.copyWith(color: const Color(0xFFA8322E)))
                    else
                      _summary(context, r.summary, r.output == null ? 'الخلاصة بعد التعديل' : 'الرد: ${r.output!.label}'),
                  ],
                  if (!live.isGuest && s.phase == LivePhase.done && s.summary.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await showEvalSheet(context, s);
                          if (mounted) setState(() {});
                        },
                        icon: const Icon(Icons.star_rounded, size: 20, color: Color(0xFFE0A800)),
                        label: Text(
                          s.eval == null
                              ? 'قيّم الجلسة'
                              : 'تقييمك: ${s.eval!.stars}★ · ${s.eval!.score}/${kEvalCriteria.length} (تعديل)',
                          style: AppTypography.label.copyWith(color: c.goldText),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: c.goldLine),
                          shape: const StadiumBorder(),
                          minimumSize: const Size(44, 44),
                        ),
                      ),
                    ),
                  ],
                  if (live.isGuest && s.phase == LivePhase.done) ...[
                    const SizedBox(height: 16),
                    Text(
                      'سجّل حسابك لتعديل الخلاصة وحفظها وتصديرها. جلستك ستنتقل لحسابك تلقائياً.',
                      style: AppTypography.label.copyWith(color: c.goldText),
                    ),
                    const SizedBox(height: 10),
                    const LiveAccountCard(),
                  ],
                  if (s.canResume) ...[
                    const SizedBox(height: 12),
                    GoldButton.primary(
                      label: '▶  استمرار',
                      expand: true,
                      onTap: () async {
                        _toBottom();
                        await s.resume();
                        if (!mounted) return;
                        if (s.phase == LivePhase.done) {
                          _toast('اكتملت الجلسة وحُفظت');
                          _toBottom();
                        }
                      },
                    ),
                  ],
                  if (s.error != null) ...[
                    const SizedBox(height: 8),
                    Text(s.error!, style: AppTypography.label.copyWith(color: const Color(0xFFA8322E))),
                  ],
                ],
              ],
            ],
              ),
              ),
              ScrollTopButton(controller: _scroll),
            ],
          ),
        ),
        if (showInput) _inputBar(context),
      ],
    );
  }

  String _statusOf(LiveSession s) => s.running ? 'running' : (s.phase == LivePhase.done ? 'done' : 'stopped');

  /// القائمة المطويّة: كل جلسة صف بسهم، الضغط يفتحها كاملة.
  List<Widget> _sessionList(BuildContext context) {
    final c = context.colors;
    final s = _s;
    final rows = [
      if (!hub.sessions.any((m) => m.id == s.id))
        SessionMeta(
          id: s.id,
          title: s.title,
          output: s.output,
          createdAt: s.createdAt,
          costMicros: s.costMicros,
          status: _statusOf(s),
        ),
      ...hub.sessions,
    ];
    return [
      Row(
        children: [
          Expanded(child: Text('جلساتك', style: AppTypography.title.copyWith(color: c.ink))),
          GoldButton.secondary(label: 'جلسة جديدة', onTap: hub.newSession),
        ],
      ),
      const SizedBox(height: 4),
      Text('اضغط على أي جلسة لفتحها كاملة، واضغط عليها مرة ثانية لطيّها.',
          style: AppTypography.caption.copyWith(color: c.inkMuted)),
      const SizedBox(height: 12),
      for (final m in rows) ...[
        _sessionTile(
          context,
          id: m.id,
          title: m.title,
          output: m.output,
          status: m.id == s.id ? _statusOf(s) : m.status,
          when: m.createdAt,
          open: false,
          onTap: () async {
            final ok = await hub.open(m.id);
            if (!mounted) return;
            if (ok) {
              hub.expand();
              if (_scroll.hasClients) _scroll.jumpTo(0);
            } else {
              _toast('تعذّر فتح الجلسة. تحقق من الاتصال');
            }
          },
        ),
        const SizedBox(height: 8),
      ],
    ];
  }

  /// صف جلسة بلون حالتها وسهم فتح/طي.
  Widget _sessionTile(
    BuildContext context, {
    required String id,
    required String title,
    required LiveOutput output,
    required String status,
    required DateTime when,
    required bool open,
    required VoidCallback onTap,
  }) {
    final c = context.colors;
    final tone = status == 'running' ? c.info : (status == 'done' ? c.ok : c.warn);
    final label = status == 'running' ? 'جارية' : (status == 'done' ? 'مكتملة' : 'متوقفة');
    final d = '${when.year}/${when.month.toString().padLeft(2, '0')}/${when.day.toString().padLeft(2, '0')}';
    return Material(
      color: Color.alphaBlend(tone.bg.withAlpha(open ? 110 : 70), c.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: tone.ink.withAlpha(140), width: 1.3),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Glyph(CategorySummary.icons[output]!, tone: outputTone(output.index), size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.isEmpty ? 'جلسة' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong.copyWith(color: c.ink, fontSize: 15)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                          decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(999)),
                          child: Text(label,
                              style: AppTypography.caption
                                  .copyWith(color: tone.ink, fontWeight: FontWeight.w600, fontSize: 11)),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text('${output.label} · ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(color: c.inkMuted)),
                        ),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(d, style: latinFigures(AppTypography.caption).copyWith(color: c.inkMuted)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded, color: c.goldText, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final c = context.colors;
    final u = LiveController.instance.user;
    final s = _s;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(widget.embedded ? 24 : 12, 8, 16, 8),
      child: Row(
        children: [
          if (!widget.embedded) ...[
            IconButton(
              tooltip: 'رجوع',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(Icons.arrow_forward_rounded, color: c.ink),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.phase == LivePhase.idle ? 'جلسة جديدة' : 'الطاولة',
                  style: AppTypography.title.copyWith(color: c.ink),
                ),
                if (u != null)
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      'رصيدك ${u.balanceLabel}',
                      style: latinFigures(AppTypography.caption).copyWith(color: c.goldText),
                    ),
                  ),
              ],
            ),
          ),
          if (s.running)
            TextButton.icon(
              onPressed: () {
                s.stop();
                _toast('أُوقفت الجلسة. «استمرار» يكملها من نفس النقطة');
              },
              icon: const Icon(Icons.stop_circle_rounded, size: 20, color: Color(0xFFA8322E)),
              label: Text('إيقاف', style: AppTypography.label.copyWith(color: const Color(0xFFA8322E))),
            )
          else if (s.phase != LivePhase.idle)
            TextButton.icon(
              onPressed: _newSession,
              icon: Icon(Icons.add_rounded, size: 18, color: c.goldText),
              label: Text('جلسة جديدة', style: AppTypography.label.copyWith(color: c.goldText)),
            ),
        ],
      ),
    );
  }

  Widget _composer(BuildContext context) {
    final c = context.colors;
    final s = _s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ما فكرتك؟', style: AppTypography.bodyStrong.copyWith(color: c.ink)),
        const SizedBox(height: 8),
        TextField(
          controller: _idea,
          minLines: 4,
          maxLines: 10,
          style: AppTypography.body.copyWith(color: c.ink),
          decoration: _fieldDecoration(context, 'اشرح فكرتك أو مشروعك بالتفصيل…'),
        ),
        const SizedBox(height: 10),
        // ملفات ومصادر: يقرؤها الأعضاء مع الفكرة.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _pickFiles,
              icon: Icon(Icons.attach_file_rounded, size: 18, color: c.goldText),
              label: Text('إرفاق ملفات', style: AppTypography.label.copyWith(color: c.goldText)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.goldLine),
                shape: const StadiumBorder(),
                minimumSize: const Size(44, 44),
              ),
            ),
            for (final a in s.attachments)
              InputChip(
                label: Text(a.name, overflow: TextOverflow.ellipsis),
                labelStyle: AppTypography.caption.copyWith(color: c.ink),
                backgroundColor: c.surfaceSoft,
                side: BorderSide(color: c.border),
                onDeleted: () => setState(() => s.attachments.remove(a)),
              ),
            for (final e in _loading.entries)
              Chip(
                avatar: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    value: e.value <= 0 ? null : e.value,
                    strokeWidth: 2.6,
                    color: c.goldLine,
                    backgroundColor: c.border,
                  ),
                ),
                label: Text('${e.key} · ${(e.value * 100).round()}%', overflow: TextOverflow.ellipsis),
                labelStyle: AppTypography.caption.copyWith(color: c.inkMuted),
                backgroundColor: c.surface,
                side: BorderSide(color: c.goldLine),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _sources,
          minLines: 1,
          maxLines: 4,
          onChanged: (v) => s.sources = v,
          style: AppTypography.body.copyWith(color: c.ink),
          decoration: _fieldDecoration(context, 'مصادر (اختياري): روابط أو مراجع أو ملاحظات…'),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, box) {
          final w = (box.maxWidth - 16) / 3;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in LiveOutput.values)
                SizedBox(
                  width: w,
                  child: Material(
                    color: s.output == o ? c.surfaceSoft : c.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: s.output == o ? c.goldLine : c.border, width: s.output == o ? 1.5 : 1),
                    ),
                    child: InkWell(
                      customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      onTap: () {
                        final msg = _outputBlock(o);
                        if (msg != null) _toast(msg);
                        setState(() => s.output = o);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        child: Column(
                          children: [
                            Glyph(CategorySummary.icons[o]!, tone: outputTone(o.index), size: 40),
                            const SizedBox(height: 6),
                            Text(o.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption
                                    .copyWith(color: s.output == o ? c.goldText : c.ink, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
        const SizedBox(height: 16),
        GoldButton.primary(label: 'ابدأ النقاش', expand: true, onTap: _start),
      ],
    );
  }

  Widget _ideaCard(BuildContext context) {
    final c = context.colors;
    final s = _s;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('الفكرة', style: AppTypography.label.copyWith(color: c.inkMuted)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.goldLine),
                ),
                child: Text(s.output.label, style: AppTypography.caption.copyWith(color: c.goldText)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(s.idea, style: AppTypography.body.copyWith(color: c.ink)),
          if (s.attachments.isNotEmpty || s.sources.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in s.attachments)
                  Chip(
                    avatar: Icon(Icons.description_outlined, size: 16, color: c.goldText),
                    label: Text(a.name),
                    labelStyle: AppTypography.caption.copyWith(color: c.ink),
                    backgroundColor: c.surface,
                    side: BorderSide(color: c.border),
                  ),
                if (s.sources.trim().isNotEmpty)
                  Chip(
                    avatar: Icon(Icons.link_rounded, size: 16, color: c.goldText),
                    label: const Text('مصادر'),
                    labelStyle: AppTypography.caption.copyWith(color: c.ink),
                    backgroundColor: c.surface,
                    side: BorderSide(color: c.border),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(BuildContext context, String hint) {
    final c = context.colors;
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.body.copyWith(color: c.inkMuted),
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.all(14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c.goldLine, width: 1.5),
      ),
    );
  }

  /// شريط الكتابة السفلي: مداخلة أثناء النقاش، أو طلب تعديل بعد الخلاصة.
  Widget _inputBar(BuildContext context) {
    final c = context.colors;
    final s = _s;
    final busy = s.phase == LivePhase.revising || s.phase == LivePhase.summary;
    final pick = !s.discussing && s.phase == LivePhase.done;
    final fmt = _replyAs == s.output ? null : _replyAs;
    final hint = s.discussing
        ? 'تدخّل في النقاش… (يقرؤها الأعضاء)'
        : fmt == null
            ? 'اطلب تعديلاً على الخلاصة…'
            : 'اكتب طلبك، والرد بيكون ${fmt.label}…';
    final bar = Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _note,
              enabled: !busy,
              minLines: 1,
              maxLines: 4,
              style: AppTypography.body.copyWith(color: c.ink),
              decoration: _fieldDecoration(context, busy ? 'انتظر قليلاً…' : hint)
                  .copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
            ),
          ),
          const SizedBox(width: 8),
          GoldButton.primary(
            label: s.discussing ? 'مداخلة' : 'إرسال',
            onTap: busy ? null : _send,
          ),
        ],
      ),
    );
    if (!pick) return bar;
    // بعد الخلاصة: اختيار صيغة الرد الجديد على نفس الجلسة.
    final c2 = context.colors;
    Widget chip(LiveOutput? o, String label) {
      final on = (o == null && fmt == null) || (o != null && o == fmt);
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: on,
          showCheckmark: false,
          labelStyle: AppTypography.caption.copyWith(color: on ? c2.goldText : c2.ink, fontWeight: FontWeight.w600),
          backgroundColor: c2.surface,
          selectedColor: c2.surfaceSoft,
          side: BorderSide(color: on ? c2.goldLine : c2.border),
          shape: const StadiumBorder(),
          onSelected: (_) {
            if (o != null) {
              final msg = _outputBlock(o);
              if (msg != null) _toast(msg);
            }
            setState(() => _replyAs = o);
          },
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: c2.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              Text('صيغة الرد: ', style: AppTypography.caption.copyWith(color: c2.inkMuted)),
              chip(null, 'تعديل الخلاصة'),
              for (final o in LiveOutput.values)
                if (o != s.output) chip(o, o.label),
            ]),
          ),
        ),
        bar,
      ],
    );
  }

  Widget _phaseBar(BuildContext context) {
    final c = context.colors;
    final s = _s;
    return Row(
      children: [
        if (s.running)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: c.goldLine),
            ),
          ),
        Expanded(
          child: Text(s.phaseLabel, style: AppTypography.bodyStrong.copyWith(color: c.goldText)),
        ),
        if (s.saved && !s.running)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Text('محفوظة', style: AppTypography.caption.copyWith(color: const Color(0xFF1F6B4A))),
          ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            formatMicros(s.costMicros),
            style: latinFigures(AppTypography.label).copyWith(color: c.inkMuted),
          ),
        ),
      ],
    );
  }

  Widget _bubble(BuildContext context, LiveEntry e) {
    final c = context.colors;
    final m = _member(e.seat);
    final name = c.memberName(e.seat);
    // إطار كامل بلون العضو وظل خفيف بلونه، مثل إطار الخلاصة الذهبي.
    final ring = e.seat.palette.discEnd;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: name.withAlpha(200), width: 1.4),
        boxShadow: [BoxShadow(color: ring.withAlpha(38), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Container(
          color: c.surface,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MemberAvatar(member: m, size: 30, isSpeaking: e.pending),
                  const SizedBox(width: 8),
                  Text(m.title, style: AppTypography.bodyStrong.copyWith(color: name)),
                  const Spacer(),
                  Text(
                    e.round == 1 ? 'الجولة ١' : 'التصحيح',
                    style: AppTypography.caption.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (e.pending)
                Text('يفكّر…', style: AppTypography.label.copyWith(color: c.inkMuted))
              else if (e.error != null)
                Text('تعذّر الرد: ${e.error}',
                    style: AppTypography.label.copyWith(color: const Color(0xFFA8322E)))
              else
                RichTextView(e.text),
            ],
          ),
        ),
      ),
    );
  }

  /// لون طلبات المستخدم: بنفسجي خارج ألوان الأعضاء حتى يتميّز عنهم.
  static const _userInk = Color(0xFF7B4FB8);

  Widget _userBubble(BuildContext context, String label, String text) {
    final c = context.colors;
    // بعرض المستطيل كاملاً مثل بطاقات الأعضاء، وبنفس المسافات.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(_userInk.withAlpha(14), c.surface),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _userInk.withAlpha(190), width: 1.4),
        boxShadow: [BoxShadow(color: _userInk.withAlpha(30), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: c.brightness == Brightness.dark ? const Color(0xFF3A3F55) : const Color(0xFFE9E9EE),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(label,
                style: AppTypography.caption.copyWith(color: c.ink, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          Text(text, style: AppTypography.body.copyWith(color: c.ink)),
        ],
      ),
    );
  }

  Widget _runningBar(BuildContext context, LiveSession s) {
    final c = context.colors;
    final left = s.entries.where((e) => e.pending).map((e) => LiveSession.seatTitle(e.seat)).toList();
    return Row(
      children: [
        Expanded(
          child: _waiting(
            context,
            left.isEmpty
                ? 'ينتقل النقاش للمرحلة التالية…'
                : '${s.phase == LivePhase.round2 ? 'جولة التصحيح' : 'الجولة الأولى'}: باقي ${left.join('، ')}',
          ),
        ),
        TextButton.icon(
          onPressed: s.stop,
          icon: Icon(Icons.stop_circle_outlined, size: 18, color: c.goldText),
          label: Text('إيقاف', style: AppTypography.label.copyWith(color: c.goldText)),
        ),
      ],
    );
  }

  Widget _waiting(BuildContext context, String text) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.goldLine),
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: AppTypography.label.copyWith(color: c.inkMuted))),
        ],
      ),
    );
  }

  /// المسجّل: نسخ وحفظ كملف. الزائر: نسخ مرة واحدة لجلسة جرت الآن فقط.
  Widget _summaryActions(BuildContext context, String text) {
    final c = context.colors;
    final live = LiveController.instance;
    final s = _s;
    if (!live.isRegistered) {
      final canCopy = s.ranHere && !s.guestCopied;
      if (!canCopy) {
        return Text(
          'النسخ والتصدير بعد تسجيل الدخول.',
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(color: c.inkMuted),
        );
      }
      return GoldButton.secondary(
        label: 'نسخ (مرة واحدة)',
        expand: true,
        onTap: () {
          Clipboard.setData(ClipboardData(text: copyText(text)));
          setState(() => s.guestCopied = true);
          _toast('نُسخت الخلاصة. سجّل لتنسخ وتصدّر متى شئت');
        },
      );
    }
    return Row(
      children: [
        Expanded(
          child: GoldButton.secondary(
            label: 'نسخ',
            expand: true,
            onTap: () {
              Clipboard.setData(ClipboardData(text: copyText(text)));
              _toast('نُسخت الخلاصة كاملة');
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PopupMenuButton<ExportFormat>(
            tooltip: 'حفظ كملف',
            position: PopupMenuPosition.under,
            color: context.colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: context.colors.goldLine),
            ),
            onSelected: (f) => exportText(context, _s.title, text, format: f),
            itemBuilder: (_) => [
              for (final (f, label, icon, tone) in const [
                (ExportFormat.word, 'Word (جداول حقيقية)', Icons.description_rounded, GlyphTone.blue),
                (ExportFormat.pdf, 'PDF', Icons.picture_as_pdf_rounded, GlyphTone.copper),
                (ExportFormat.txt, 'نص TXT', Icons.notes_rounded, GlyphTone.slate),
              ])
                PopupMenuItem(
                  value: f,
                  child: Row(
                    children: [
                      Glyph(icon, tone: tone, size: 30),
                      const SizedBox(width: 10),
                      Text(label, style: AppTypography.label.copyWith(color: context.colors.ink)),
                    ],
                  ),
                ),
            ],
            child: IgnorePointer(
              child: GoldButton.secondary(label: 'حفظ ▾', expand: true, onTap: () {}),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context, String text, String title, {bool cut = false}) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.goldLine, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x29A8832F), blurRadius: 30, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MemberAvatar(member: _member(MemberId.chair), size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: AppTypography.title.copyWith(color: c.goldText)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichTextView(text),
          if (cut) ...[
            const SizedBox(height: 8),
            Text('الخلاصة طويلة وقد تكون اختُصرت. اطلب «أكمل الخلاصة» في التعديل.',
                style: AppTypography.caption.copyWith(color: c.inkMuted)),
          ],
          const SizedBox(height: 12),
          _summaryActions(context, text),
        ],
      ),
    );
  }
}

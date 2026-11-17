import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/mock_data.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/gold_button.dart';
import '../widgets/member_avatar.dart';
import '../widgets/project_card.dart' show latinFigures;
import 'live_account_card.dart';
import 'live_api.dart';
import 'live_session.dart';
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
  final ScrollController _scroll = ScrollController();
  String _shownId = '';

  LiveHub get hub => LiveHub.instance;
  LiveSession get _s => hub.current;

  @override
  void initState() {
    super.initState();
    _syncFields();
    hub.addListener(_syncFields);
  }

  @override
  void dispose() {
    hub.removeListener(_syncFields);
    _idea.dispose();
    _note.dispose();
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
    _note.clear();
  }

  Future<void> _start() async {
    FocusScope.of(context).unfocus();
    final s = _s;
    s.idea = _idea.text;
    if (s.idea.trim().length < 10) {
      _toast('اكتب فكرتك بتفصيل أكثر (10 أحرف على الأقل)');
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
      _note.clear();
      _toBottom();
      await s.revise(t);
      if (!mounted || !identical(s, _s)) return;
      final last = s.revisions.isEmpty ? null : s.revisions.last;
      _toast(last?.error == null ? 'طُبّق التعديل وحُفظ' : 'تعذّر التعديل: ${last!.error}');
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

  Widget _page(BuildContext context) {
    final c = context.colors;
    final s = _s;
    final live = LiveController.instance;
    final canRun = live.isSignedIn && (live.user?.hasPlan ?? false);
    final showInput = canRun && (s.discussing || s.phase == LivePhase.done || s.phase == LivePhase.revising);

    return Column(
      children: [
        _header(context),
        Expanded(
          child: Stack(
            children: [
              ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              if (!canRun && s.phase == LivePhase.idle) ...[
                Text(
                  'لتشغيل جلسة حقيقية: أنشئ حسابك وفعّل باقتك بالكود.',
                  style: AppTypography.body.copyWith(color: c.inkMuted),
                ),
                const SizedBox(height: 12),
                const LiveAccountCard(),
              ] else ...[
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
                  if (s.phase == LivePhase.summary) _waiting(context, 'رئيس الجلسة يكتب الخلاصة…'),
                  if (s.summary.isNotEmpty) _summary(context, s.summary, 'الخلاصة الموحّدة', cut: s.summaryCut),
                  for (final r in s.revisions) ...[
                    const SizedBox(height: 14),
                    _userBubble(context, 'طلب تعديل', r.request),
                    const SizedBox(height: 10),
                    if (r.pending)
                      _waiting(context, 'رئيس الجلسة يطبّق التعديل…')
                    else if (r.error != null)
                      Text('تعذّر التعديل: ${r.error}',
                          style: AppTypography.label.copyWith(color: const Color(0xFFA8322E)))
                    else
                      _summary(context, r.summary, 'الخلاصة بعد التعديل'),
                  ],
                  if (s.canRetrySummary) ...[
                    const SizedBox(height: 12),
                    GoldButton.primary(
                      label: 'أكمل إلى الخلاصة',
                      expand: true,
                      onTap: () async {
                        await s.writeSummary();
                        if (mounted && s.phase == LivePhase.done) _toBottom();
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
              ScrollTopButton(controller: _scroll),
            ],
          ),
        ),
        if (showInput) _inputBar(context),
      ],
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
          if (s.phase != LivePhase.idle)
            TextButton.icon(
              onPressed: s.running ? null : _newSession,
              icon: Icon(Icons.add_rounded, size: 18, color: s.running ? c.inkMuted : c.goldText),
              label: Text(
                'جلسة جديدة',
                style: AppTypography.label.copyWith(color: s.running ? c.inkMuted : c.goldText),
              ),
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
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in LiveOutput.values)
              ChoiceChip(
                label: Text(o.label),
                selected: s.output == o,
                onSelected: (_) => setState(() => s.output = o),
                labelStyle: AppTypography.label.copyWith(color: s.output == o ? c.goldText : c.ink),
                selectedColor: c.surfaceSoft,
                backgroundColor: c.surface,
                side: BorderSide(color: s.output == o ? c.goldLine : c.border),
                showCheckmark: false,
              ),
          ],
        ),
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
    final hint = s.discussing ? 'تدخّل في النقاش… (يقرؤها الأعضاء)' : 'اطلب تعديلاً على الخلاصة…';
    return Container(
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
    // حد موحّد مع الزوايا، والحافة الملونة 3px داخل القص (حد غير موحّد لا يقبل زوايا).
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            border: BorderDirectional(start: BorderSide(color: name, width: 3)),
          ),
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

  Widget _userBubble(BuildContext context, String label, String text) {
    final c = context.colors;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.goldLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.caption.copyWith(color: c.goldText)),
            const SizedBox(height: 4),
            Text(text, style: AppTypography.body.copyWith(color: c.ink)),
          ],
        ),
      ),
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
          Text(text, style: AppTypography.label.copyWith(color: c.inkMuted)),
        ],
      ),
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
          Row(
            children: [
              Expanded(
                child: GoldButton.secondary(
                  label: 'نسخ',
                  expand: true,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: text));
                    _toast('نُسخت الخلاصة كاملة');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GoldButton.secondary(
                  label: 'حفظ كملف',
                  expand: true,
                  onTap: () => exportText(context, _s.title, text),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

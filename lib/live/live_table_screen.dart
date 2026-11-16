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

/// طاولة حقيقية: المستخدم يكتب فكرته، والأعضاء الخمسة يتناقشون فعلياً عبر
/// السيرفر، ثم يكتب رئيس الجلسة الخلاصة.
class LiveTableScreen extends StatefulWidget {
  const LiveTableScreen({super.key});

  @override
  State<LiveTableScreen> createState() => _LiveTableScreenState();
}

class _LiveTableScreenState extends State<LiveTableScreen> {
  final LiveSession _s = LiveSession();
  final TextEditingController _idea = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _s.dispose();
    _idea.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Member _member(MemberId id) =>
      MockData.members.firstWhere((m) => m.id == id, orElse: () => MockData.members.first);

  Future<void> _start() async {
    FocusScope.of(context).unfocus();
    _s.idea = _idea.text;
    if (_s.idea.trim().length < 10) {
      _toast('اكتب فكرتك بتفصيل أكثر (10 أحرف على الأقل)');
      return;
    }
    await _s.start();
    if (!mounted) return;
    if (_s.phase == LivePhase.done) {
      _toast('اكتملت الجلسة');
      _toBottom();
    } else if (_s.phase == LivePhase.failed) {
      _toast('توقفت الجلسة: ${_s.error ?? ''}');
    }
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
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_s, LiveController.instance]),
          builder: (context, _) {
            final live = LiveController.instance;
            final canRun = live.isSignedIn && (live.user?.hasPlan ?? false);
            return Column(
              children: [
                _header(context),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    children: [
                      if (!canRun) ...[
                        Text(
                          'لتشغيل جلسة حقيقية: أنشئ حسابك وفعّل باقتك بالكود.',
                          style: AppTypography.body.copyWith(color: c.inkMuted),
                        ),
                        const SizedBox(height: 12),
                        const LiveAccountCard(),
                      ] else ...[
                        _composer(context),
                        if (_s.phase != LivePhase.idle) ...[
                          const SizedBox(height: 20),
                          _phaseBar(context),
                          const SizedBox(height: 12),
                          for (final e in _s.entries) ...[
                            _bubble(context, e),
                            const SizedBox(height: 10),
                          ],
                          if (_s.phase == LivePhase.summary) _waiting(context, 'رئيس الجلسة يكتب الخلاصة…'),
                          if (_s.summary.isNotEmpty) _summary(context),
                          if (_s.canRetrySummary) ...[
                            const SizedBox(height: 12),
                            GoldButton.primary(
                              label: 'أكمل إلى الخلاصة',
                              expand: true,
                              onTap: () async {
                                await _s.writeSummary();
                                if (mounted && _s.phase == LivePhase.done) _toBottom();
                              },
                            ),
                          ],
                          if (_s.error != null) ...[
                            const SizedBox(height: 8),
                            Text(_s.error!,
                                style: AppTypography.label.copyWith(color: const Color(0xFFA8322E))),
                          ],
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final c = context.colors;
    final u = LiveController.instance.user;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 24, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'رجوع',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_forward_rounded, color: c.ink),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text('جلسة جديدة', style: AppTypography.title.copyWith(color: c.ink)),
          ),
          if (u != null)
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                u.balanceLabel,
                style: latinFigures(AppTypography.label).copyWith(color: c.goldText),
              ),
            ),
        ],
      ),
    );
  }

  Widget _composer(BuildContext context) {
    final c = context.colors;
    final locked = _s.running;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ما فكرتك؟', style: AppTypography.bodyStrong.copyWith(color: c.ink)),
        const SizedBox(height: 8),
        TextField(
          controller: _idea,
          enabled: !locked,
          minLines: 4,
          maxLines: 10,
          style: AppTypography.body.copyWith(color: c.ink),
          decoration: InputDecoration(
            hintText: 'اشرح فكرتك أو مشروعك بالتفصيل…',
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
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in LiveOutput.values)
              ChoiceChip(
                label: Text(o.label),
                selected: _s.output == o,
                onSelected: locked ? null : (_) => setState(() => _s.output = o),
                labelStyle: AppTypography.label.copyWith(
                  color: _s.output == o ? c.goldText : c.ink,
                ),
                selectedColor: c.surfaceSoft,
                backgroundColor: c.surface,
                side: BorderSide(color: _s.output == o ? c.goldLine : c.border),
                showCheckmark: false,
              ),
          ],
        ),
        const SizedBox(height: 16),
        GoldButton.primary(
          label: locked ? 'الطاولة تتناقش…' : (_s.phase == LivePhase.idle ? 'ابدأ النقاش' : 'جلسة جديدة بنفس الفكرة'),
          expand: true,
          onTap: locked ? null : _start,
        ),
      ],
    );
  }

  Widget _phaseBar(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        if (_s.running)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: c.goldLine),
            ),
          ),
        Expanded(
          child: Text(_s.phaseLabel, style: AppTypography.bodyStrong.copyWith(color: c.goldText)),
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            formatMicros(_s.costMicros),
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
            SelectableText(e.text, style: AppTypography.body.copyWith(color: c.ink)),
        ],
          ),
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

  Widget _summary(BuildContext context) {
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
                child: Text('الخلاصة الموحّدة',
                    style: AppTypography.title.copyWith(color: c.goldText)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(_s.summary, style: AppTypography.body.copyWith(color: c.ink)),
          if (_s.summaryCut) ...[
            const SizedBox(height: 8),
            Text('الخلاصة طويلة وقد تكون اختُصرت.',
                style: AppTypography.caption.copyWith(color: c.inkMuted)),
          ],
          const SizedBox(height: 12),
          GoldButton.secondary(
            label: 'نسخ الخلاصة',
            expand: true,
            onTap: () {
              Clipboard.setData(ClipboardData(text: _s.summary));
              _toast('نُسخت الخلاصة');
            },
          ),
        ],
      ),
    );
  }
}

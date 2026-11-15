import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/gold_button.dart';
import '../widgets/member_avatar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/project_card.dart' show latinFigures;
import '../widgets/round_table.dart';
import '../widgets/status_chip.dart';
import '../widgets/summary_card.dart';

/// شاشة الطاولة.
///
/// لا مؤقّت هنا: المحاكاة تعيش عند مالكها [AppState] (خطوة 1200ms تُمرَّر
/// من app.dart)، وتتوقف عند مغادرة التبويب أو الخلفية عبر setTableVisible.
/// تتخلّص الشاشة من ScrollController ومستمعه فقط.
///
/// - الشريط المصغّر مركّب دائماً أعلى الـ Stack (فيبقى قياسه ممكناً)،
///   ويُخفى باللمس والدلالات حتى تعبر الدائرة أعلى منطقة التمرير.
/// - القفز إلى الخلاصة: jumpToSummary ثم إطار ثم animateTo بإزاحة مقاسة
///   (400ms، easeOutCubic) مع حارس جيل يُبطَل عند الإعادة وتغيّر المشروع.
class TableScreen extends StatefulWidget {
  const TableScreen({super.key});

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  final GlobalKey _tableKey = GlobalKey();
  final GlobalKey _summaryKey = GlobalKey();
  final GlobalKey _barKey = GlobalKey();

  bool _showBar = false;
  double _barHeight = 0;
  int _jumpGen = 0;
  String? _lastProjectId;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_evaluateBar);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = AppStateScope.of(context).activeProjectId;
    if (_lastProjectId != null && id != _lastProjectId) {
      // تغيّر المشروع: يُبطَل أي قفز قديم وتعود الشاشة إلى الأعلى.
      _jumpGen++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    }
    _lastProjectId = id;
  }

  @override
  void dispose() {
    _scroll.removeListener(_evaluateBar);
    _scroll.dispose();
    super.dispose();
  }

  // ---- القياس -----------------------------------------------------------

  void _measureBar() {
    final box = _barKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final h = box.size.height;
    if ((h - _barHeight).abs() > 0.5) {
      setState(() => _barHeight = h);
    }
  }

  /// منطقية واحدة: أسفل الدائرة صار عند أعلى منطقة التمرير أو فوقه.
  void _evaluateBar() {
    final t = _tableKey.currentContext?.findRenderObject();
    final v = _viewportKey.currentContext?.findRenderObject();
    if (t is! RenderBox || v is! RenderBox) return;
    if (!t.attached || !v.attached || !t.hasSize || !v.hasSize) return;
    final bottom =
        t.localToGlobal(Offset(0, t.size.height), ancestor: v).dy;
    final show = bottom <= 0;
    if (show != _showBar) setState(() => _showBar = show);
  }

  // ---- الأفعال ----------------------------------------------------------

  void _restart(AppState app) {
    _jumpGen++;
    app.restartSimulation();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _jumpToSummary(AppState app) {
    final gen = ++_jumpGen;
    app.jumpToSummary();
    _scrollToSummary(gen, 0);
  }

  void _scrollToSummary(int gen, int attempt) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || gen != _jumpGen) return;

      final sBox = _summaryKey.currentContext?.findRenderObject();
      final vBox = _viewportKey.currentContext?.findRenderObject();
      final ready = sBox is RenderBox &&
          sBox.hasSize &&
          vBox is RenderBox &&
          vBox.hasSize &&
          _scroll.hasClients;

      if (!ready) {
        // إطار ثانٍ واحد ثم توقف، بلا حلقة.
        if (attempt < 1) {
          _scrollToSummary(gen, attempt + 1);
          WidgetsBinding.instance.scheduleFrame();
        }
        return;
      }

      final summaryTop =
          sBox.localToGlobal(Offset.zero, ancestor: vBox).dy;
      final measured = _barKey.currentContext?.findRenderObject();
      final barH = (measured is RenderBox && measured.hasSize)
          ? measured.size.height
          : _barHeight;

      final raw = _scroll.offset + summaryTop - barH - 12;
      final target =
          raw.clamp(0.0, _scroll.position.maxScrollExtent).toDouble();
      if ((target - _scroll.offset).abs() < 0.5) return;

      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
  }

  // ---- البناء -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final app = AppStateScope.of(context);
    final name = app.activeProject?.name ?? '';

    if (app.messageCount == 0) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: AppTypography.displayL.copyWith(color: c.ink)),
            const SizedBox(height: 16),
            Text(
              'لا يوجد سيناريو تجريبي مُعدّ لهذا المشروع',
              style: AppTypography.body.copyWith(color: c.inkMuted),
            ),
          ],
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measureBar();
      _evaluateBar();
    });

    final centerId = app.centerMemberId;
    final bottomPad = math.max(96.0, _barHeight + 12);
    final messages = app.visibleMessages;
    final summary = app.summaryVisible ? app.summary : null;

    return Stack(
      key: _viewportKey,
      fit: StackFit.expand,
      children: [
        SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- الرأس
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style:
                              AppTypography.displayL.copyWith(color: c.ink),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            StatusChip.tag(label: 'سيناريو تجريبي مُعدّ مسبقاً'),
                            StatusChip.tag(label: 'وضع تجريبي — دون اتصال'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GoldButton.disc(
                    label: 'إعادة المحاكاة',
                    icon: _RestartIcon(color: c.goldText),
                    onTap: () => _restart(app),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ---- شريط الجولات وزر الخلاصة
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (var r = 1; r <= app.roundCount; r++)
                    _RoundChip(
                      round: r,
                      progress: app.summaryVisible
                          ? RoundProgress.done
                          : app.roundProgress(r),
                    ),
                  GoldButton.secondary(
                    label: 'انتقل إلى الخلاصة',
                    onTap: () => _jumpToSummary(app),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ---- دائرة الطاولة
              KeyedSubtree(
                key: _tableKey,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: RoundTable(
                    members: MockData.members,
                    centerId: centerId,
                    pulsing: app.isRunning,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ---- الرسائل
              for (var i = 0; i < messages.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _Appear(
                  key: ValueKey(messages[i].id),
                  child: MessageBubble(
                    message: messages[i],
                    sender: MockData.memberOf(messages[i].senderId),
                  ),
                ),
              ],

              // ---- الخلاصة
              if (summary != null) ...[
                const SizedBox(height: 24),
                KeyedSubtree(
                  key: _summaryKey,
                  child: _Appear(
                    key: ValueKey('summary-${summary.projectId}'),
                    child: SummaryCard(
                      summary: summary,
                      onSave: app.saveSummary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ---- الشريط المصغّر: مركّب دائماً، يُخفى باللمس والدلالات.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !_showBar,
            child: ExcludeSemantics(
              excluding: !_showBar,
              child: AnimatedSlide(
                offset: _showBar ? Offset.zero : const Offset(0, -1),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _showBar ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: _MiniBar(
                    barKey: _barKey,
                    centerId: centerId,
                    running: app.isRunning,
                    progress: app.progress,
                    onSummary: () => _jumpToSummary(app),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ظهور تدريجي قصير لعنصر جديد. المفتاح الثابت يمنع إعادة التشغيل
/// عند إعادة بناء العناصر القائمة.
class _Appear extends StatelessWidget {
  const _Appear({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// جولة في الشريط: مكتملة (علامة صح)، نشطة، أو معلّقة.
class _RoundChip extends StatelessWidget {
  const _RoundChip({required this.round, required this.progress});

  final int round;
  final RoundProgress progress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final number = toArabicDigits('$round');

    late final Color bg;
    late final Color ink;
    late final BorderSide side;
    late final String semantic;

    switch (progress) {
      case RoundProgress.done:
        bg = c.ok.bg;
        ink = c.ok.ink;
        side = BorderSide.none;
        semantic = 'الجولة $number مكتملة';
      case RoundProgress.active:
        bg = c.surfaceSoft;
        ink = c.goldText;
        side = BorderSide(color: c.goldLine);
        semantic = 'الجولة $number نشطة';
      case RoundProgress.pending:
        bg = c.surface;
        ink = c.inkMuted;
        side = BorderSide(color: c.border);
        semantic = 'الجولة $number لم تبدأ';
    }

    return Semantics(
      label: semantic,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: bg,
          shape: StadiumBorder(side: side),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(number, style: AppTypography.label.copyWith(color: ink)),
              if (progress == RoundProgress.done) ...[
                const SizedBox(width: 6),
                CheckMarkIcon(size: 14, color: ink),
              ],
              if (progress == RoundProgress.active) ...[
                const SizedBox(width: 6),
                Text('نشطة', style: AppTypography.caption.copyWith(color: ink)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// الشريط المصغّر الثابت: صفّان بارتفاع طبيعي قابل للتمدد.
/// الأول الأقراص الستة، والثاني المتحدث والتقدم وزر «الخلاصة ↓».
class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.barKey,
    required this.centerId,
    required this.running,
    required this.progress,
    required this.onSummary,
  });

  final Key barKey;
  final MemberId? centerId;
  final bool running;
  final double progress;
  final VoidCallback onSummary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pct = (progress * 100).round();
    final speaker = centerId == null ? null : MockData.memberOf(centerId!);

    return Container(
      key: barKey,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final m in MockData.members)
                MemberAvatar(
                  member: m,
                  size: 40,
                  isSpeaking: running && m.id == centerId,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(
                child: Text(
                  speaker?.title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    color: speaker == null
                        ? c.inkMuted
                        : c.memberName(speaker.id),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: toArabicDigits('التقدم $pct بالمئة'),
                excludeSemantics: true,
                child: SizedBox(
                  width: 48,
                  height: 6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Stack(
                      children: [
                        Positioned.fill(child: ColoredBox(color: c.track)),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FractionallySizedBox(
                            widthFactor: progress.clamp(0.0, 1.0).toDouble(),
                            heightFactor: 1,
                            child:
                                const ColoredBox(color: AppColors.gold500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ExcludeSemantics(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '$pct%',
                    style: latinFigures(AppTypography.caption)
                        .copyWith(color: c.inkMuted),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GoldButton.secondary(
                label: 'الخلاصة',
                icon: _DownArrowIcon(color: c.ink),
                onTap: onSummary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// رموز مرسومة بـ CustomPainter (بلا Icons ولا إيموجي)
// ---------------------------------------------------------------------------

class _DownArrowIcon extends StatelessWidget {
  const _DownArrowIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 16,
        height: 16,
        child: CustomPaint(painter: _DownArrowPainter(color)),
      ),
    );
  }
}

class _DownArrowPainter extends CustomPainter {
  const _DownArrowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.drawLine(const Offset(12, 4.5), const Offset(12, 19), line);
    final head = Path()
      ..moveTo(5.5, 12.5)
      ..lineTo(12, 19)
      ..lineTo(18.5, 12.5);
    canvas.drawPath(head, line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DownArrowPainter old) => old.color != color;
}

class _RestartIcon extends StatelessWidget {
  const _RestartIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CustomPaint(painter: _RestartPainter(color)),
      ),
    );
  }
}

/// سهم دائري: قوس بزاوية 4.6 راديان ورأس سهم عند نهايته.
class _RestartPainter extends CustomPainter {
  const _RestartPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);

    const center = Offset(12, 12);
    const radius = 7.5;
    const start = 0.9;
    const sweep = 4.6;
    const end = start + sweep;

    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      line,
    );

    // رأس السهم عند نهاية القوس، باتجاه المماس.
    final ex = center.dx + radius * math.cos(end);
    final ey = center.dy + radius * math.sin(end);
    final tx = -math.sin(end);
    final ty = math.cos(end);
    final nx = math.cos(end);
    final ny = math.sin(end);
    final head = Path()
      ..moveTo(ex + tx * 3.4, ey + ty * 3.4)
      ..lineTo(ex + nx * 3.0, ey + ny * 3.0)
      ..lineTo(ex - nx * 3.0, ey - ny * 3.0)
      ..close();
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(head, fill);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RestartPainter old) => old.color != color;
}

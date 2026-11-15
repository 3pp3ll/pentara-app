import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/project_card.dart' show latinFigures;

/// المختبر. المؤشرات الأربعة وقمع الجاهزية ثوابت لا تتبع الجلسة المختارة؛
/// الضغط على جلسة يحرّك أشرطة «جودة النقاش» الخمسة فقط (400ms).
class LabScreen extends StatelessWidget {
  const LabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final app = AppStateScope.of(context);
    final stats = MockData.labStats;
    final selected = app.selectedEvaluation;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('المختبر', style: AppTypography.displayL.copyWith(color: c.ink)),
          const SizedBox(height: 16),

          // ---- المؤشرات 2×2
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MetricCard(
                    title: 'الاختبارات',
                    value: '${stats.totalTests}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    title: 'متوسط الدرجة',
                    value: '${stats.averageScore}',
                    unit: '/100',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MetricCard(
                    title: 'تكلفة المحاكاة',
                    value: formatSar(stats.simulationCostHalalas)
                        .replaceAll(' ر.س', ''),
                    unit: 'ر.س',
                    unitIsArabic: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    title: 'متوسط المدة',
                    value: '${stats.averageDurationSeconds}',
                    unit: 'ث',
                    unitIsArabic: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ---- جودة النقاش
          _Panel(
            title: 'جودة النقاش',
            subtitle: selected.title,
            child: Column(
              children: [
                for (var i = 0; i < MockData.qualityDimensions.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _ScoreBar(
                    label: MockData.qualityDimensions[i],
                    score: selected.scores[i],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- جاهزية المنتج
          _Panel(
            title: 'جاهزية المنتج',
            child: Column(
              children: [
                for (var i = 0; i < MockData.readinessFunnel.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _FunnelBar(row: MockData.readinessFunnel[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ---- آخر الجلسات المقيَّمة
          Text(
            'آخر الجلسات المقيَّمة',
            style: AppTypography.title.copyWith(color: c.ink),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < MockData.evaluations.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _EvaluationRow(
              evaluation: MockData.evaluations[i],
              selected: MockData.evaluations[i].id == app.selectedEvaluationId,
              onTap: () => AppStateScope.read(context)
                  .selectEvaluation(MockData.evaluations[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.title.copyWith(color: c.ink)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: AppTypography.caption.copyWith(color: c.inkMuted),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// مؤشر: الرقم غربي متساوي العرض داخل LTR، والوحدة منفصلة.
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    this.unit,
    this.unitIsArabic = false,
  });

  final String title;
  final String value;
  final String? unit;
  final bool unitIsArabic;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.label.copyWith(color: c.inkMuted)),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 4,
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  value,
                  style: AppTypography.metric.copyWith(color: c.ink),
                ),
              ),
              if (unit != null)
                Directionality(
                  textDirection:
                      unitIsArabic ? TextDirection.rtl : TextDirection.ltr,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      unit!,
                      style: (unitIsArabic
                              ? AppTypography.label
                              : latinFigures(AppTypography.label))
                          .copyWith(color: c.inkMuted),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// شريط درجة: ينتقل من قيمته السابقة إلى الجديدة (400ms) بلا مفتاح يتبع الجلسة.
class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: AppTypography.label.copyWith(color: c.ink)),
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '$score',
                style: latinFigures(AppTypography.label)
                    .copyWith(color: c.inkMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _AnimatedBar(
          fraction: score / 100.0,
          fill: AppColors.gold500,
        ),
      ],
    );
  }
}

class _FunnelBar extends StatelessWidget {
  const _FunnelBar({required this.row});

  final ReadinessCount row;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = c.tone(row.stage.tone);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(row.stage.label,
                  style: AppTypography.label.copyWith(color: c.ink)),
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${row.count}',
                style: latinFigures(AppTypography.label)
                    .copyWith(color: tone.ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _AnimatedBar(fraction: row.count / 12.0, fill: tone.ink),
      ],
    );
  }
}

class _AnimatedBar extends StatelessWidget {
  const _AnimatedBar({required this.fraction, required this.fill});

  final double fraction;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: fraction.clamp(0.0, 1.0).toDouble()),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => SizedBox(
        height: 8,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: c.track)),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: t,
                  heightFactor: 1,
                  child: ColoredBox(color: fill),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvaluationRow extends StatelessWidget {
  const _EvaluationRow({
    required this.evaluation,
    required this.selected,
    required this.onTap,
  });

  final Evaluation evaluation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final overlay = c.goldLine.withAlpha(31);
    final radius = BorderRadius.circular(20);

    return Semantics(
      button: true,
      selected: selected,
      label: '${evaluation.title}، المتوسط ${evaluation.average}',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? c.surfaceSoft : c.surface,
            borderRadius: radius,
            border: Border.all(
              color: selected ? c.goldLine : c.border,
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            highlightColor: overlay,
            hoverColor: overlay,
            focusColor: overlay,
            splashColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            evaluation.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyStrong
                                .copyWith(color: c.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            evaluation.whenLabel,
                            style: AppTypography.caption
                                .copyWith(color: c.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '${evaluation.average}',
                        style: latinFigures(AppTypography.bodyStrong)
                            .copyWith(color: c.goldText),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

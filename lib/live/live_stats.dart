import 'package:flutter/material.dart';

import '../widgets/glyph.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/project_card.dart' show latinFigures;
import 'live_api.dart';
import 'live_session.dart';

/// أعداد المشاريع حسب الفئة: للمسجّل من جلساته، وللزائر من إحصاءات كل المستخدمين.
class CategoryCounts {
  const CategoryCounts(this.counts, {required this.mine});
  final Map<LiveOutput, int> counts;
  final bool mine;

  int get total => counts.values.fold(0, (a, b) => a + b);

  static CategoryCounts current() {
    final live = LiveController.instance;
    final counts = {for (final o in LiveOutput.values) o: 0};
    if (live.isRegistered) {
      for (final m in LiveHub.instance.sessions) {
        counts[m.output] = (counts[m.output] ?? 0) + 1;
      }
      return CategoryCounts(counts, mine: true);
    }
    final by = live.globalStats['byOutput'];
    if (by is Map) {
      for (final o in LiveOutput.values) {
        counts[o] = (by[o.name] as num?)?.toInt() ?? 0;
      }
    }
    return CategoryCounts(counts, mine: false);
  }
}

/// صف ملخص الفئات (المشاريع والمختبر).
class CategorySummary extends StatelessWidget {
  const CategorySummary({super.key});

  static const Map<LiveOutput, IconData> icons = {
    LiveOutput.text: Icons.notes_rounded,
    LiveOutput.plan: Icons.description_rounded,
    LiveOutput.research: Icons.travel_explore_rounded,
    LiveOutput.appIdea: Icons.phone_iphone_rounded,
    LiveOutput.web: Icons.language_rounded,
    LiveOutput.study: Icons.query_stats_rounded,
    LiveOutput.auto: Icons.auto_awesome_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: Listenable.merge([LiveController.instance, LiveHub.instance]),
      builder: (context, _) {
        final data = CategoryCounts.current();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              data.mine ? 'قراءات حسابك' : 'قراءات كل المستخدمين',
              style: AppTypography.caption.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, box) {
              // 7 أنواع: في الشاشات الضيقة تتمرر أفقياً بدل ما تنضغط.
              final n = LiveOutput.values.length;
              final fit = (box.maxWidth - 8 * (n - 1)) / n;
              final w = fit >= 72 ? fit : 76.0;
              final row = Row(
              children: [
                for (final o in LiveOutput.values) ...[
                  if (o != LiveOutput.values.first) const SizedBox(width: 8),
                  SizedBox(
                    width: w,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.border),
                      ),
                      child: Column(
                        children: [
                          Glyph(icons[o]!, tone: outputTone(o.index), size: 34),
                          const SizedBox(height: 6),
                          Text(
                            '${data.counts[o] ?? 0}',
                            style: latinFigures(AppTypography.bodyStrong).copyWith(color: c.ink, fontSize: 16),
                          ),
                          Text(
                            o.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(color: c.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
              return fit >= 72 ? row : SingleChildScrollView(scrollDirection: Axis.horizontal, child: row);
            }),
          ],
        );
      },
    );
  }
}

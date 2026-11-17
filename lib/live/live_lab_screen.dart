import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/project_card.dart' show latinFigures;
import 'live_api.dart';
import 'live_projects_screen.dart';
import 'live_session.dart';
import 'live_stats.dart';
import 'scroll_top.dart';

/// «المختبر»: تحليل حقيقي لكل ما جرى في التطبيق (كل المستخدمين)،
/// وبعد الدخول تظهر قراءات الحساب وآخر جلساته.
class LiveLabScreen extends StatefulWidget {
  const LiveLabScreen({super.key, required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  State<LiveLabScreen> createState() => _LiveLabScreenState();
}

class _LiveLabScreenState extends State<LiveLabScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge([LiveController.instance, LiveHub.instance]),
        builder: (context, _) {
          final live = LiveController.instance;
          final st = live.globalStats;
          final sessions = (st['sessions'] as num?)?.toInt() ?? 0;
          final cost = (st['costMicros'] as num?)?.toInt() ?? 0;
          final avg = sessions == 0 ? 0 : cost ~/ sessions;
          final global = CategoryCounts.current();
          LiveOutput? top;
          final by = st['byOutput'];
          if (by is Map) {
            var best = 0;
            for (final o in LiveOutput.values) {
              final n = (by[o.name] as num?)?.toInt() ?? 0;
              if (n > best) {
                best = n;
                top = o;
              }
            }
          }

          return Stack(
            children: [
              RefreshIndicator(
                color: c.goldLine,
                onRefresh: () async {
                  await live.loadStats();
                  if (live.isSignedIn) await LiveHub.instance.loadList();
                },
                child: ListView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  children: [
                    Text('المختبر', style: AppTypography.displayL.copyWith(color: c.ink)),
                    const SizedBox(height: 4),
                    Text('تحليل حي لكل جلسات بنتارا', style: AppTypography.label.copyWith(color: c.inkMuted)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _tile(context, 'الجلسات', '$sessions', latin: true)),
                        const SizedBox(width: 10),
                        Expanded(child: _tile(context, 'متوسط تكلفة الجلسة', formatMicros(avg), latin: true)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _tile(context, 'إجمالي التكلفة', formatMicros(cost), latin: true)),
                        const SizedBox(width: 10),
                        Expanded(child: _tile(context, 'الأكثر طلباً', top?.category ?? '—')),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('توزيع المشاريع', style: AppTypography.title.copyWith(color: c.ink)),
                    const SizedBox(height: 10),
                    _bars(context, global, sessions),
                    if (live.isRegistered) ...[
                      const SizedBox(height: 24),
                      Text('حسابك', style: AppTypography.title.copyWith(color: c.ink)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _tile(context, 'جلساتك', '${LiveHub.instance.sessions.length}', latin: true),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _tile(context, 'ما صرفته', formatMicros(live.user?.spentMicros ?? 0),
                                latin: true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('آخر جلساتك', style: AppTypography.title.copyWith(color: c.ink)),
                      const SizedBox(height: 10),
                      LiveRecentSessions(onOpen: widget.onOpen),
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

  Widget _tile(BuildContext context, String label, String value, {bool latin = false}) {
    final c = context.colors;
    final style = (latin ? latinFigures(AppTypography.metric) : AppTypography.title).copyWith(color: c.ink);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption.copyWith(color: c.inkMuted)),
          const SizedBox(height: 6),
          Directionality(
            textDirection: latin ? TextDirection.ltr : Directionality.of(context),
            child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
          ),
        ],
      ),
    );
  }

  /// أشرطة الفئات من إحصاءات كل المستخدمين.
  Widget _bars(BuildContext context, CategoryCounts mine, int total) {
    final c = context.colors;
    final by = LiveController.instance.globalStats['byOutput'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          for (final o in LiveOutput.values) ...[
            if (o != LiveOutput.values.first) const SizedBox(height: 12),
            Builder(builder: (context) {
              final n = by is Map ? ((by[o.name] as num?)?.toInt() ?? 0) : 0;
              final f = total == 0 ? 0.0 : n / total;
              return Row(
                children: [
                  Icon(CategorySummary.icons[o], size: 18, color: c.goldText),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 84,
                    child: Text(o.category, style: AppTypography.label.copyWith(color: c.ink)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: LinearProgressIndicator(
                        value: f,
                        minHeight: 10,
                        backgroundColor: c.track,
                        color: const Color(0xFFC9A75A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    child: Text('$n',
                        textAlign: TextAlign.end,
                        style: latinFigures(AppTypography.label).copyWith(color: c.inkMuted)),
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}

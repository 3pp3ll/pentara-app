import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/gold_button.dart';
import '../widgets/project_card.dart';

enum _SortOrder {
  original('الافتراضي'),
  costAsc('الأقل تكلفة'),
  costDesc('الأعلى تكلفة');

  const _SortOrder(this.label);

  final String label;
}

/// شاشة المشاريع. البحث والتصفية والترتيب محلية هنا (لا AppState)،
/// فلا يوقظ كل حرف الطاولة والمختبر. تبقى حالتها عند تبديل التبويب لأن
/// الغلاف يحتفظ بها داخل IndexedStack.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key, required this.onOpenProject});

  /// يستقبل معرّف المشروع. الغلاف وحده يختاره ويفتح الطاولة.
  final ValueChanged<String> onOpenProject;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  /// الرقائق: الأربع الحرفية من المرجع أولاً من اليمين، ثم بقية الحالات
  /// تلبيةً لطلب «الحالات الست» (تأويل). «مرفوض» بلا مشروع فتظهر رسالة فراغ.
  static const List<ProjectStatus?> _filters = [
    null, // الكل
    ProjectStatus.discussing,
    ProjectStatus.testing,
    ProjectStatus.verified,
    ProjectStatus.needsFix,
    ProjectStatus.idea,
    ProjectStatus.rejected,
  ];

  final TextEditingController _controller = TextEditingController();
  String _query = '';
  ProjectStatus? _filter;
  _SortOrder _sort = _SortOrder.original;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// فلتر ثم بحث ثم ترتيب، على نسخة. لا يُعدَّل MockData.projects.
  /// التعادل بفهرس الأصل تصاعدياً في الاتجاهين لأن List.sort غير مستقر.
  List<Project> _visible() {
    final q = _query.trim().toLowerCase();
    final entries = MockData.projects.asMap().entries.where((e) {
      final p = e.value;
      if (_filter != null && p.status != _filter) return false;
      if (q.isNotEmpty &&
          !p.name.toLowerCase().contains(q) &&
          !p.description.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();

    switch (_sort) {
      case _SortOrder.original:
        break;
      case _SortOrder.costAsc:
        entries.sort((a, b) {
          final d = a.value.costCents.compareTo(b.value.costCents);
          return d != 0 ? d : a.key.compareTo(b.key);
        });
      case _SortOrder.costDesc:
        entries.sort((a, b) {
          final d = b.value.costCents.compareTo(a.value.costCents);
          return d != 0 ? d : a.key.compareTo(b.key);
        });
    }
    return entries.map((e) => e.value).toList();
  }

  /// يصفّر البحث والتصفية فقط، لا الترتيب.
  void _clear() {
    _controller.clear();
    setState(() {
      _query = '';
      _filter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final visible = _visible();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'المشاريع',
            style: AppTypography.displayL.copyWith(color: c.ink),
          ),
          const SizedBox(height: 4),
          Text(
            toArabicDigits(
              '${visible.length} من ${MockData.projects.length} مشاريع',
            ),
            style: AppTypography.label.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: 16),

          // ---- البحث
          TextField(
            controller: _controller,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            style: AppTypography.body.copyWith(color: c.ink),
            decoration: InputDecoration(
              hintText: 'ابحث في المشاريع',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: ExcludeSemantics(
                  child: CustomPaint(
                    size: const Size(20, 20),
                    painter: _SearchPainter(c.inkMuted),
                  ),
                ),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ),
          const SizedBox(height: 12),

          // ---- رقائق التصفية (صف أفقي بلا reverse: «الكل» في أقصى اليمين).
          // SingleChildScrollView يأخذ ارتفاعه من الرقائق فيتسع مع تكبير الخط.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < _filters.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _SelectChip(
                    label: _filters[i]?.label ?? 'الكل',
                    selected: _filter == _filters[i],
                    onTap: () => setState(() => _filter = _filters[i]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ---- الترتيب: رقائق ظاهرة في صف مستقل.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'ترتيب:',
                  style: AppTypography.label.copyWith(color: c.inkMuted),
                ),
                const SizedBox(width: 8),
                for (final s in _SortOrder.values) ...[
                  _SelectChip(
                    label: s.label,
                    selected: _sort == s,
                    onTap: () => setState(() => _sort = s),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- القائمة
          Expanded(
            child: visible.isEmpty
                ? _EmptyState(onClear: _clear)
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final p = visible[i];
                      return ProjectCard(
                        project: p,
                        onTap: () => widget.onOpenProject(p.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// رقاقة قابلة للضغط بهدف لمس 44 على الأقل. (StatusChip للعرض فقط.)
/// النشطة: surfaceSoft وحد goldLine ونص goldText.
class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final overlay = c.goldLine.withAlpha(31);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: ShapeDecoration(
            color: selected ? c.surfaceSoft : c.surface,
            shape: StadiumBorder(
              side: BorderSide(color: selected ? c.goldLine : c.border),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            highlightColor: overlay,
            hoverColor: overlay,
            focusColor: overlay,
            splashColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: AppTypography.label
                        .copyWith(color: selected ? c.goldText : c.ink),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'لا توجد مشاريع مطابقة',
              textAlign: TextAlign.center,
              style: AppTypography.title.copyWith(color: c.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'جرّب تغيير كلمة البحث أو الحالة المختارة.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: 16),
            GoldButton.secondary(
              label: 'مسح البحث والتصفية',
              onTap: onClear,
            ),
          ],
        ),
      ),
    );
  }
}

/// عدسة البحث: خط على شبكة 24×24.
class _SearchPainter extends CustomPainter {
  const _SearchPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawCircle(const Offset(10.5, 10.5), 6.5, line);
    canvas.drawLine(const Offset(15.5, 15.5), const Offset(21, 21), line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SearchPainter old) => old.color != color;
}

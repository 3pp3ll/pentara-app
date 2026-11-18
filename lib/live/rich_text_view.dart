import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// يعرض نص الأعضاء والخلاصة منسّقاً: عناوين، خط عريض، نقاط، قوائم مرقّمة،
/// جداول، وخط فاصل. بديل خفيف لمكتبات Markdown.
class RichTextView extends StatelessWidget {
  const RichTextView(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = AppTypography.body.copyWith(color: c.ink);
    final lines = text.replaceAll('\r', '').split('\n');
    final out = <Widget>[];
    var i = 0;

    while (i < lines.length) {
      final raw = lines[i];
      final line = raw.trim();

      if (line.isEmpty) {
        i++;
        continue;
      }

      // جدول: أسطر متتالية تبدأ بـ |
      if (line.startsWith('|')) {
        final rows = <List<String>>[];
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          final r = lines[i].trim();
          final cells = r.length < 2 ? <String>[''] : r.substring(1, r.endsWith('|') ? r.length - 1 : r.length).split('|');
          final isRule = cells.every((x) => RegExp(r'^\s*:?-{2,}:?\s*$').hasMatch(x));
          if (!isRule) rows.add(cells.map((x) => x.trim()).toList());
          i++;
        }
        if (rows.isNotEmpty) {
          try {
            out.add(_table(context, rows, base));
          } catch (_) {
            // احتياط: لو تعذّر رسم الجدول يظهر نصه كما هو بدل أن تختفي الخلاصة.
            out.add(Text(rows.map((r) => r.join(' | ')).join('\n'), style: base));
          }
        }
        continue;
      }

      // خط فاصل
      if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(line)) {
        out.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Divider(color: c.border, height: 1),
        ));
        i++;
        continue;
      }

      // عنوان
      final h = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
      if (h != null) {
        final level = h.group(1)!.length;
        final style = (level <= 2 ? AppTypography.title : AppTypography.bodyStrong)
            .copyWith(color: level <= 2 ? c.goldText : c.ink);
        out.add(Padding(
          padding: EdgeInsets.only(top: out.isEmpty ? 0 : 14, bottom: 6),
          child: Text.rich(_inline(h.group(2)!, style)),
        ));
        i++;
        continue;
      }

      // نقطة أو رقم (مع مسافة بادئة للمستويات)
      final indent = raw.length - raw.trimLeft().length;
      final bullet = RegExp(r'^[-*•]\s+(.*)$').firstMatch(line);
      final number = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(line);
      if (bullet != null || number != null) {
        final marker = bullet != null ? '•' : '${number!.group(1)}.';
        final body = bullet != null ? bullet.group(1)! : number!.group(2)!;
        out.add(Padding(
          padding: EdgeInsetsDirectional.only(start: indent >= 2 ? 18.0 : 0, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text(marker, style: base.copyWith(color: c.goldText, fontWeight: FontWeight.w600)),
              ),
              Expanded(child: Text.rich(_inline(body, base))),
            ],
          ),
        ));
        i++;
        continue;
      }

      // اقتباس
      if (line.startsWith('>')) {
        out.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsetsDirectional.only(start: 12),
          decoration: BoxDecoration(
            border: BorderDirectional(start: BorderSide(color: c.goldLine, width: 3)),
          ),
          child: Text.rich(_inline(line.substring(1).trim(), base.copyWith(color: c.inkMuted))),
        ));
        i++;
        continue;
      }

      out.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text.rich(_inline(line, base)),
      ));
      i++;
    }

    return SelectionArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: out),
    );
  }

  /// **عريض** و`كود` داخل السطر.
  static TextSpan _inline(String s, TextStyle style) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*|__(.+?)__|`([^`]+)`');
    var last = 0;
    for (final m in re.allMatches(s)) {
      if (m.start > last) spans.add(TextSpan(text: s.substring(last, m.start)));
      if (m.group(3) != null) {
        spans.add(TextSpan(
          text: m.group(3),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
        ));
      } else {
        spans.add(TextSpan(
          text: m.group(1) ?? m.group(2),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ));
      }
      last = m.end;
    }
    if (last < s.length) spans.add(TextSpan(text: s.substring(last)));
    return TextSpan(style: style, children: spans);
  }

  Widget _table(BuildContext context, List<List<String>> rows, TextStyle base) {
    return LayoutBuilder(builder: (context, box) {
      final cols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
      // الجوال: جدول بعمود نص طويل يصير قائمة منسدلة (كل صف بطاقة تنفتح بتفاصيلها).
      if (box.maxWidth < 600 && cols >= 2 && rows.length >= 2) {
        return _MobileTable(rows: rows, cols: cols);
      }
      return _wideTable(context, rows, cols);
    });
  }

  /// عرض كل عمود حسب طول نصه: الأعمدة القصيرة صغيرة، والطويل يأخذ المساحة.
  static Map<int, TableColumnWidth> _widths(List<List<String>> rows, int cols) {
    final avg = List<double>.filled(cols, 0);
    for (var k = 0; k < cols; k++) {
      var sum = 0;
      var n = 0;
      for (final r in rows.skip(1)) {
        if (k < r.length) {
          sum += r[k].length;
          n++;
        }
      }
      avg[k] = n == 0 ? 4 : sum / n;
    }
    return {for (var k = 0; k < cols; k++) k: FlexColumnWidth(avg[k].clamp(4, 60).toDouble())};
  }

  Widget _wideTable(BuildContext context, List<List<String>> rows, int cols) {
    final c = context.colors;
    final small = AppTypography.label.copyWith(color: c.ink);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: _widths(rows, cols),
        border: TableBorder(horizontalInside: BorderSide(color: c.border), verticalInside: BorderSide(color: c.border)),
        children: [
          for (var r = 0; r < rows.length; r++)
            TableRow(
              decoration: BoxDecoration(color: r == 0 ? c.surfaceSoft : null),
              children: [
                for (var k = 0; k < cols; k++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Text.rich(_inline(
                      k < rows[r].length ? rows[r][k] : '',
                      r == 0 ? small.copyWith(fontWeight: FontWeight.w600) : small,
                    )),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// جدول الجوال: صف لكل عنصر بقيمه القصيرة وسهم؛ الضغط يفتح النص الطويل بعرض الشاشة
/// ويقفل المفتوح قبله تلقائياً.
class _MobileTable extends StatefulWidget {
  const _MobileTable({required this.rows, required this.cols});

  final List<List<String>> rows;
  final int cols;

  @override
  State<_MobileTable> createState() => _MobileTableState();
}

class _MobileTableState extends State<_MobileTable> {
  int? _open;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final head = widget.rows.first;
    final data = widget.rows.skip(1).toList();
    // العمود الأطول نصاً هو التفاصيل، والباقي يظهر في رأس البطاقة.
    var longK = widget.cols - 1;
    var best = -1.0;
    for (var k = 0; k < widget.cols; k++) {
      var sum = 0;
      for (final r in data) {
        if (k < r.length) sum += r[k].length;
      }
      final a = data.isEmpty ? 0.0 : sum / data.length;
      if (a > best) {
        best = a;
        longK = k;
      }
    }
    String cell(List<String> r, int k) => k < r.length ? r[k] : '';
    final small = AppTypography.label.copyWith(color: c.ink);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // رأس الأعمدة صغير
          Container(
            color: c.surfaceSoft,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              children: [
                for (var k = 0; k < widget.cols; k++)
                  if (k != longK)
                    Expanded(
                      child: Text(cell(head, k),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(color: c.inkMuted, fontWeight: FontWeight.w600)),
                    ),
                Icon(Icons.unfold_more_rounded, size: 16, color: c.inkMuted),
              ],
            ),
          ),
          for (var r = 0; r < data.length; r++) ...[
            Divider(height: 1, color: c.border),
            InkWell(
              onTap: () => setState(() => _open = _open == r ? null : r),
              child: Container(
                color: _open == r ? c.surfaceSoft.withAlpha(140) : null,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    for (var k = 0; k < widget.cols; k++)
                      if (k != longK)
                        Expanded(
                          child: Text.rich(
                            RichTextView._inline(
                              cell(data[r], k),
                              k == 0 || (longK == 0 && k == 1)
                                  ? small.copyWith(fontWeight: FontWeight.w700)
                                  : small.copyWith(color: c.goldText, fontWeight: FontWeight.w600),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    AnimatedRotation(
                      turns: _open == r ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down_rounded, color: c.goldText),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _open == r
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                      color: c.surfaceSoft.withAlpha(140),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cell(head, longK),
                              style: AppTypography.caption.copyWith(color: c.inkMuted, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text.rich(RichTextView._inline(cell(data[r], longK), AppTypography.body.copyWith(color: c.ink, height: 1.6))),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ],
      ),
    );
  }
}

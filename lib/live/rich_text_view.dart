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
          final cells = r.substring(1, r.endsWith('|') ? r.length - 1 : r.length).split('|');
          final isRule = cells.every((x) => RegExp(r'^\s*:?-{2,}:?\s*$').hasMatch(x));
          if (!isRule) rows.add(cells.map((x) => x.trim()).toList());
          i++;
        }
        if (rows.isNotEmpty) out.add(_table(context, rows, base));
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
    final c = context.colors;
    final cols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    final small = AppTypography.label.copyWith(color: c.ink);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: {
          for (var k = 0; k < cols; k++)
            k: k == 0 ? const FlexColumnWidth(2) : const FlexColumnWidth(1),
        },
        border: TableBorder(horizontalInside: BorderSide(color: c.border)),
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
